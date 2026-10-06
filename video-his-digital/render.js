// Renderiza escenas.html cuadro por cuadro y lo codifica a MP4 con ffmpeg.
// Uso: node render.js [salida.mp4] [fps]          (video completo)
//      node render.js --stills 3,9,15,...           (capturas PNG de prueba)
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const html = 'file://' + path.join(__dirname, 'escenas.html') + '?static';

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  await page.goto(html);
  await page.evaluate(() => document.fonts.ready);

  if (args[0] === '--stills') {
    const outDir = path.join(__dirname, 'stills');
    fs.mkdirSync(outDir, { recursive: true });
    for (const t of args[1].split(',').map(Number)) {
      await page.evaluate((t) => window.render(t), t);
      await page.screenshot({ path: path.join(outDir, `t${String(t).padStart(5, '0')}.png`) });
    }
    await browser.close();
    return;
  }

  const out = args[0] || path.join(__dirname, 'his-digital-video.mp4');
  const fps = +(args[1] || 30);
  const audio = path.join(__dirname, 'musica.wav');
  const duration = await page.evaluate(() => window.DURATION);
  const frames = Math.round(duration * fps);

  const ff = spawn('ffmpeg', [
    '-y', '-loglevel', 'error',
    '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-',
    ...(fs.existsSync(audio) ? ['-i', audio, '-c:a', 'aac', '-b:a', '192k', '-shortest'] : []),
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-preset', 'medium',
    '-movflags', '+faststart', out,
  ], { stdio: ['pipe', 'inherit', 'inherit'] });

  for (let f = 0; f < frames; f++) {
    await page.evaluate((t) => window.render(t), f / fps);
    const buf = await page.screenshot({ type: 'jpeg', quality: 92 });
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
    if (f % 150 === 0) console.log(`cuadro ${f}/${frames}`);
  }
  ff.stdin.end();
  await new Promise((r) => ff.on('close', r));
  await browser.close();
  console.log('listo:', out);
})();
