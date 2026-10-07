# Prompt para el editor de código (C# / ASP.NET)

Copia todo lo que está dentro del bloque y pégalo en tu editor de código con IA
(Copilot, Cursor, etc.). Adjunta también el archivo `sql/PF_nuevos_seguimiento_12m.sql`.

```text
CONTEXTO
Trabajo en un proyecto C# / ASP.NET que consulta SQL Server (base BDHIS_MINSA, tabla
dbo.DATA_HIS del HIS MINSA, y el catálogo cgsalud2025.dbo.establecimiento).
Adjunto el script SQL "PF_nuevos_seguimiento_12m.sql", ya probado en SQL Server 2019.
Genera un NOMINAL de usuarios NUEVOS de planificación familiar y su seguimiento a 12 meses.
Devuelve UNA sola tabla: una fila por persona (DNI) y método iniciado.

QUÉ NECESITO
1. Convertir el script en un procedimiento almacenado dbo.usp_PF_NominalSeguimiento con
   estos parámetros (los valores entre paréntesis son los valores por defecto):
     @ini_cohorte DATE ('2025-01-01')   primer inicio a considerar
     @fin_cohorte DATE ('2026-12-31')   último inicio a considerar
     @fec_corte   DATE (hoy)            fecha de corte de la información
     @dias_nuevo  INT  (365)            días sin el mismo método para ser NUEVO
     @dias_seg    INT  (365)            duración del seguimiento
     @edad_min    INT  (15)
     @edad_max    INT  (49)
     @tol_valida  INT  (5)              ± días para que una entrega sea válida
     @gracia_busqueda INT (5)           la siguiente entrega se busca desde programada − estos días
   - Quitar USE y los DECLARE/SET de parámetros; mantener SET NOCOUNT ON y las tablas
     temporales. Crear el SP con SET ANSI_NULLS ON y SET QUOTED_IDENTIFIER ON.
   - NO cambiar la lógica ni los nombres de columnas de salida.
2. Capa de datos en C#: método async que ejecute el SP con parámetros tipados
   (Dapper o ADO.NET con SqlParameter; nunca concatenar SQL). CommandTimeout alto
   (600 s), porque la consulta recorre DATA_HIS de varios años.
3. Modelo C# NominalPF con las columnas de salida (lista abajo). Las 13 entregas como
   List<EntregaPF> (N, Programada, Fecha, Validez, Registro), armada a partir de las
   columnas E1..E13 del resultado.
4. Página (ASP.NET Core MVC/Razor; si el proyecto es Web Forms o MVC 5, adapta) con:
   - Filtros: rango de inicio, fecha de corte, método, estado, microred, establecimiento, DNI.
   - Tabla con paginación. Columnas fijas a la izquierda (DNI, Método, Estado).
   - Colores por validez de cada entrega: 0 gris (no tiene), 1 verde (válido),
     2 ámbar (observado). Si no hay fecha real pero sí programada, mostrar la programada
     en cursiva (cita pendiente).
   - Botón "Exportar a Excel" (ClosedXML o EPPlus) con exactamente las mismas columnas.
5. Configuración: cadena de conexión en appsettings.json / Web.config, no en el código.

REGLAS DE NEGOCIO (las implementa el SQL; sirven para entender y probar)
- Entrega válida (igual que el indicador N° 13 - DL 1153): fila de DATA_HIS con
  Codigo_Item del método, Tipo_Diagnostico 'D' o 'R', Tipo_Doc_Paciente = 1 (DNI), y la
  MISMA cita (id_cita + anio) tiene otra fila con Codigo_Item = '99208' y valor_lab = 'TA'.
  Se agrupa por persona + método + día (una entrega por día).
- Catálogo de métodos:
    Código                  Método                 Tipo        Meta  Días/unidad  Tolerancia  Usa cantidad
    99208.05                INYECTABLE TRIMESTRAL  CORTO        4     90          30          No
    99208.04                INYECTABLE MENSUAL     CORTO       13     28           7          No
    99208.13                ORAL COMBINADO         CORTO       13     28           7          Sí (ciclos en valor_lab)
    99208.02                CONDON MASCULINO       CORTO       12     30           7          No (mensual)
    99208.06                CONDON FEMENINO        CORTO       12     30           7          No (mensual)
    58300                   DIU                    LARGO        1     -            -          No
    58300.01                SIU                    LARGO        1     -            -          No
    11975                   IMPLANTE               LARGO        1     -            -          No
    58600, 58605, 58611     LIGADURA DE TROMPAS    DEFINITIVO   1     -            -          No
    55250                   VASECTOMIA             DEFINITIVO   1     -            -          No
  Cantidad: si el método usa cantidad, se toma valor_lab como entero (vacío/0/no numérico = 1);
  si no, cada entrega vale 1.
- Usuario NUEVO: entrega del método sin otra entrega del MISMO método en los 365 días
  previos (por eso se lee desde el año anterior a @ini_cohorte). Debe tener entre
  @edad_min y @edad_max años (Tipo_Edad = 'A') y su inicio debe caer entre @ini_cohorte y
  @fin_cohorte.
- Exclusión de gestantes (igual que el script original): se descarta a toda persona con
  Codigo_Item en (Z349, Z3491, Z3492, Z3493, Z359, Z3591, Z3592, Z3593) o valor_lab = 'G'
  en el periodo (DNI, 15-49 años).
- Seguimiento: desde el inicio hasta inicio + 364 días. E1 = inicio; E2..E13 = siguientes
  entregas del mismo método dentro de ese año.
- Entregas muy juntas: la siguiente entrega se busca desde (fecha programada −
  @gracia_busqueda), es decir trimestral ≥ 85 días, mensual ≥ 23, condón ≥ 25, oral ≥ 23 por
  ciclo. Las registradas antes NO cuentan como otra entrega; se agregan al Registro de la
  entrega anterior como " [extra: dd/MM/yyyy D/código/lab; ...]". DIU, SIU, implante y AQV
  solo tienen E1 (las repeticiones salen como extra en E1_Registro).
- Fecha programada de la entrega k = fecha de la entrega k-1 + CEILING(cantidad de la
  entrega k-1 × días/unidad).
- Validez de cada entrega: 0 = no tiene entrega; 1 = válido (inicio, o |fecha real −
  programada| ≤ @tol_valida); 2 = observado (más de @tol_valida días después de la
  programada). Las observadas
  TAMBIÉN cuentan como entregas para la meta y el avance.
- Entregas que faltan: después de la última entrega real se proyectan las fechas
  programadas siguientes (última + n × CEILING(cantidad última × días/unidad)) hasta la meta
  anual; en el oral, mientras la fecha caiga dentro del año de seguimiento. Máximo E13.
  En esas columnas: Fecha = NULL y Validez = 0.
- Próxima cita = última entrega + CEILING(cantidad última × días/unidad).
- Fecha de evaluación = la menor entre (inicio + 364) y @fec_corte.
- Días de atraso = fecha de evaluación − próxima cita (0 si no hay atraso).
- Avance_pct = MIN(100, unidades × 100 / meta).
- Estado (en este orden):
    LARGO -> 'PROTEGIDO - LARGA DURACION'; DEFINITIVO -> 'PROTEGIDO - DEFINITIVO'
    unidades >= meta -> 'COMPLETO'
    fecha evaluación > próxima cita + tolerancia y recibió OTRO método después de su
      última entrega dentro del año -> 'CAMBIO DE METODO'
    fecha evaluación > próxima cita + tolerancia -> 'ABANDONO'
    año no cumplido y fecha de corte > próxima cita -> 'EN SEGUIMIENTO - CITA VENCIDA'
    año no cumplido -> 'EN SEGUIMIENTO - AL DIA'
    si no -> 'INCOMPLETO'
- Último método: el último método válido que recibió la persona hasta la fecha de corte
  (cualquier método).
- Registro: "Tipo_Diagnostico/Codigo_Item/valor_lab" de la entrega; si ese día hay varios
  registros del método, separados por coma (ej. "D/99208.05/1, R/99208.05/").
- Establecimiento: LEFT JOIN por TRY_CONVERT(INT, Codigo_Unico) en ambos lados.

COLUMNAS DE SALIDA (en este orden, 66 columnas)
MicroRed, Renaes, Establecimiento, DNI, Sexo, Edad_inicio, Metodo, Fecha_inicio, Estado,
Entregas, Entregas_observadas, Avance_pct, Ultima_entrega, Proxima_cita, Dias_atraso,
Ultimo_metodo, Fecha_ultimo_metodo, E1_Registro,
y para k = 2..13: Ek_Programada (date), Ek_Fecha (date, null), Ek_Validez (int 0/1/2),
Ek_Registro (string, null).
Orden: Metodo, Fecha_inicio, DNI.

CASOS DE PRUEBA (resultado esperado; úsalos en pruebas unitarias o de integración)
1. Trimestral 10/01/2025, 10/04/2025, 09/07/2025, 08/10/2025 (todas con 99208-TA):
   Estado COMPLETO, Entregas 4, Observadas 0, Avance 100;
   E2 programada 10/04 validez 1; E3 09/07 validez 1; E4 programada 07/10, real 08/10, validez 1.
2. Condón 02/01/2025, 10/01, 01/02, 20/02, 05/03, 15/04:
   E1_Registro "D/99208.02/ [extra: 10/01/2025 D/99208.02/]";
   E2 programada 01/02 real 01/02 validez 1, Registro con [extra: 20/02/2025 ...];
   E3 programada 03/03 real 05/03 validez 1; E4 programada 04/04 real 15/04 validez 2;
   Entregas 4, Observadas 1, Próxima cita 15/05/2025.
2b. Condón 01/10/2026 y 05/10/2026: Entregas 1, E1_Registro con [extra: 05/10/2026 ...],
   E2 programada 31/10/2026 sin fecha real.
3. Condón masculino una sola entrega el 02/01/2025:
   Estado ABANDONO, Avance 8, Próxima cita 01/02/2025, Días de atraso 334;
   E2..E12 programadas 01/02, 03/03, 02/04, 02/05, 01/06, 01/07, 31/07, 30/08, 29/09,
   29/10, 28/11 (Fecha NULL, Validez 0); E13 programada NULL.
4. Oral combinado 01/03/2026 con 3 ciclos y 26/05/2026 con 3 ciclos:
   E2 programada 24/05/2026, real 26/05, validez 1; proyectadas E3 18/08/2026,
   E4 10/11/2026, E5 02/02/2027.
5. Inyectable mensual 01/03/2025 y 01/04/2025, implante 20/05/2025:
   fila MENSUAL -> 'CAMBIO DE METODO', Ultimo_metodo IMPLANTE (20/05/2025);
   fila IMPLANTE -> 'PROTEGIDO - LARGA DURACION'.
6. Trimestral 10/02/2025 SIN 99208-TA y 11/05/2025 CON TA: el inicio es el 11/05/2025.
7. Persona con trimestral en 2024-06-01 y 2025-01-05: NO aparece (no es nueva).
8. Persona con código Z3491 en el periodo: NO aparece (gestante excluida).

RESTRICCIONES
- No reimplementar en C# la lógica del SQL: el cálculo vive en el SP; C# solo ejecuta,
  mapea, muestra y exporta.
- Manejar NULL en todas las fechas y registros de E2..E13.
- Fechas en formato dd/MM/yyyy en pantalla y en Excel.
- Probar con los casos anteriores antes de dar por terminado.
```
