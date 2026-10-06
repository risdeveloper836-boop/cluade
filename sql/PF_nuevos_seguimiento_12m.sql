/*===========================================================================================
  PLANIFICACION FAMILIAR: NOMINAL DE USUARIOS NUEVOS Y SU SEGUIMIENTO A 12 MESES

  Cohorte : personas (DNI) que INICIAN un metodo anticonceptivo moderno desde el 01/01/2025.
  Nuevo   : primera entrega del metodo sin otra entrega del MISMO metodo en los 365 dias previos.
  Excluye : gestantes, igual que el script del indicador N 13 (toda persona con codigo de
            embarazo o valor_lab = 'G' en el periodo queda fuera del nominal).
  Seguim. : 365 dias desde la fecha de inicio. Estados:
            PROTEGIDO - LARGA DURACION / DEFINITIVO (DIU, SIU, implante, AQV)
            COMPLETO                      (alcanzo la meta anual del metodo)
            CAMBIO DE METODO              (dejo el metodo y recibio otro)
            ABANDONO                      (no volvio a tiempo y no cambio de metodo)
            EN SEGUIMIENTO - AL DIA / CITA VENCIDA (aun no cumple los 12 meses)
            INCOMPLETO                    (cerro los 12 meses sin abandono, pero bajo la meta)
  Salida  : solo el nominal. Compatible con SQL Server 2012 o superior.
  Nota    : ejecutar el script COMPLETO (F5), sin seleccionar solo una parte.
===========================================================================================*/
USE BDHIS_MINSA;
SET NOCOUNT ON;

/*===================================== PARAMETROS =====================================*/
DECLARE @ini_cohorte DATE;
DECLARE @fin_cohorte DATE;
DECLARE @fec_corte   DATE;
DECLARE @dias_nuevo  INT;
DECLARE @dias_seg    INT;
DECLARE @edad_min    INT;
DECLARE @edad_max    INT;

SET @ini_cohorte = '20250101';                 /* primer inicio a considerar             */
SET @fin_cohorte = '20261231';                 /* ultimo inicio a considerar             */
SET @fec_corte   = CONVERT(DATE, GETDATE());   /* fecha de corte de la informacion       */
SET @dias_nuevo  = 365;                        /* dias sin el metodo para ser NUEVO      */
SET @dias_seg    = 365;                        /* duracion del seguimiento               */
SET @edad_min    = 15;
SET @edad_max    = 49;

/*================================ CATALOGO DE METODOS =================================
  meta_anual    : unidades que dan 1 anio de proteccion (inyectable trimestral = 4 dosis).
  dias_x_unidad : dias que protege cada unidad entregada (para calcular la proxima cita).
  tolerancia    : dias de gracia despues de la proxima cita antes de considerar ABANDONO.
=======================================================================================*/
IF OBJECT_ID('tempdb..#metodo') IS NOT NULL DROP TABLE #metodo;
CREATE TABLE #metodo(
    cod_item      VARCHAR(10) PRIMARY KEY,
    metodo        VARCHAR(40),
    tipo          VARCHAR(12),
    meta_anual    INT,
    dias_x_unidad DECIMAL(6,2),
    tolerancia    INT
);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('99208.05', 'INYECTABLE TRIMESTRAL', 'CORTO', 4, 90.00, 30);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('99208.04', 'INYECTABLE MENSUAL', 'CORTO', 13, 28.00, 7);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('99208.13', 'ORAL COMBINADO', 'CORTO', 13, 28.00, 7);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('99208.02', 'CONDON MASCULINO', 'CORTO', 100, 3.65, 15);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('99208.06', 'CONDON FEMENINO', 'CORTO', 100, 3.65, 15);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('58300', 'DIU', 'LARGO', 1, NULL, NULL);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('58300.01', 'SIU', 'LARGO', 1, NULL, NULL);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('11975', 'IMPLANTE', 'LARGO', 1, NULL, NULL);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('58600', 'LIGADURA DE TROMPAS', 'DEFINITIVO', 1, NULL, NULL);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('58605', 'LIGADURA DE TROMPAS', 'DEFINITIVO', 1, NULL, NULL);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('58611', 'LIGADURA DE TROMPAS', 'DEFINITIVO', 1, NULL, NULL);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia) VALUES ('55250', 'VASECTOMIA', 'DEFINITIVO', 1, NULL, NULL);

/* Un registro por metodo (la ligadura tiene 3 codigos) */
IF OBJECT_ID('tempdb..#metodo_param') IS NOT NULL DROP TABLE #metodo_param;
SELECT DISTINCT metodo, tipo, meta_anual, dias_x_unidad, tolerancia
INTO #metodo_param
FROM #metodo;

/*============================ 1. ENTREGAS DE METODOS (HIS) ============================
  Se lee desde el anio anterior al inicio de la cohorte para saber quien es NUEVO en enero.
  Una fila por persona + metodo + dia.
  cantidad: numero registrado en valor_lab (ciclos, condones, ampollas); si esta vacio o no
            es numerico se toma 1.
=======================================================================================*/
IF OBJECT_ID('tempdb..#entrega') IS NOT NULL DROP TABLE #entrega;
SELECT
    h.Numero_Documento_Paciente                                    AS num_doc,
    m.metodo                                                       AS metodo,
    m.tipo                                                         AS tipo,
    CONVERT(DATE, h.Fecha_Atencion)                                AS fecha,
    MAX(h.Codigo_Unico)                                            AS renaes,
    MAX(h.id_genero)                                               AS id_genero,
    MAX(CASE WHEN h.Tipo_Edad = 'A' THEN h.edad_reg END)           AS edad,
    MAX(ISNULL(NULLIF(TRY_CONVERT(INT, h.valor_lab), 0), 1))       AS cantidad
INTO #entrega
FROM BDHIS_MINSA.dbo.DATA_HIS AS h WITH (NOLOCK)
INNER JOIN #metodo AS m ON m.cod_item = h.Codigo_Item
WHERE h.anio BETWEEN YEAR(@ini_cohorte) - 1 AND YEAR(@fec_corte)
  AND h.Tipo_Doc_Paciente = 1
  AND h.Tipo_Diagnostico IN ('D', 'R')
  AND CONVERT(DATE, h.Fecha_Atencion) <= @fec_corte
GROUP BY h.Numero_Documento_Paciente, m.metodo, m.tipo, CONVERT(DATE, h.Fecha_Atencion);

CREATE CLUSTERED INDEX ix_ent ON #entrega (num_doc, metodo, fecha);

/*============================== 2. INICIOS (CASOS NUEVOS) =============================*/
IF OBJECT_ID('tempdb..#previa') IS NOT NULL DROP TABLE #previa;
SELECT
    x.num_doc, x.metodo, x.tipo, x.fecha, x.renaes, x.id_genero, x.edad,
    LAG(x.fecha) OVER (PARTITION BY x.num_doc, x.metodo ORDER BY x.fecha) AS fec_previa
INTO #previa
FROM #entrega AS x;

IF OBJECT_ID('tempdb..#inicio') IS NOT NULL DROP TABLE #inicio;
SELECT
    ROW_NUMBER() OVER (ORDER BY t.fecha, t.num_doc, t.metodo) AS id_episodio,
    t.num_doc,
    t.metodo,
    t.tipo,
    t.fecha                                AS fec_inicio,
    DATEADD(DAY, @dias_seg - 1, t.fecha)   AS fec_fin_seg,
    t.renaes                               AS renaes_inicio,
    t.id_genero,
    t.edad                                 AS edad_inicio
INTO #inicio
FROM #previa AS t
WHERE (t.fec_previa IS NULL OR DATEDIFF(DAY, t.fec_previa, t.fecha) > @dias_nuevo)
  AND t.fecha BETWEEN @ini_cohorte AND @fin_cohorte
  AND t.edad BETWEEN @edad_min AND @edad_max;

CREATE CLUSTERED INDEX ix_ini ON #inicio (num_doc, metodo, fec_inicio);

/*=========================== 2.1 SE EXCLUYEN GESTANTES ================================
  Mismo criterio que el script original: se descarta a toda persona con algun codigo de
  embarazo o con valor_lab = 'G' en el periodo.
=======================================================================================*/
DELETE FROM #inicio
WHERE num_doc IN (
    SELECT DISTINCT g.Numero_Documento_Paciente
    FROM BDHIS_MINSA.dbo.DATA_HIS AS g WITH (NOLOCK)
    WHERE g.anio BETWEEN YEAR(@ini_cohorte) AND YEAR(@fec_corte)
      AND g.Tipo_Doc_Paciente = 1
      AND g.Tipo_Edad = 'A'
      AND g.edad_reg BETWEEN @edad_min AND @edad_max
      AND (g.Codigo_Item IN ('Z349', 'Z3491', 'Z3492', 'Z3493', 'Z359',
                             'Z3591', 'Z3592', 'Z3593')
           OR g.valor_lab = 'G')
);

/*=========================== 3. ENTREGAS DENTRO DE LOS 12 MESES ========================
  mes_seg: mes de seguimiento (1 = primer mes desde el inicio ... 12 = ultimo mes)
=======================================================================================*/
IF OBJECT_ID('tempdb..#seg') IS NOT NULL DROP TABLE #seg;
SELECT
    i.id_episodio,
    e.fecha,
    e.cantidad,
    DATEDIFF(DAY, i.fec_inicio, e.fecha) * 12 / @dias_seg + 1 AS mes_seg
INTO #seg
FROM #inicio AS i
INNER JOIN #entrega AS e
        ON e.num_doc = i.num_doc
       AND e.metodo  = i.metodo
       AND e.fecha BETWEEN i.fec_inicio AND i.fec_fin_seg;

IF OBJECT_ID('tempdb..#seg_res') IS NOT NULL DROP TABLE #seg_res;
SELECT
    s.id_episodio,
    COUNT(*)                                                 AS n_entregas,
    SUM(s.cantidad)                                          AS unidades,
    MAX(s.fecha)                                             AS fec_ultima,
    SUM(CASE WHEN s.mes_seg = 1  THEN s.cantidad ELSE 0 END) AS M01,
    SUM(CASE WHEN s.mes_seg = 2  THEN s.cantidad ELSE 0 END) AS M02,
    SUM(CASE WHEN s.mes_seg = 3  THEN s.cantidad ELSE 0 END) AS M03,
    SUM(CASE WHEN s.mes_seg = 4  THEN s.cantidad ELSE 0 END) AS M04,
    SUM(CASE WHEN s.mes_seg = 5  THEN s.cantidad ELSE 0 END) AS M05,
    SUM(CASE WHEN s.mes_seg = 6  THEN s.cantidad ELSE 0 END) AS M06,
    SUM(CASE WHEN s.mes_seg = 7  THEN s.cantidad ELSE 0 END) AS M07,
    SUM(CASE WHEN s.mes_seg = 8  THEN s.cantidad ELSE 0 END) AS M08,
    SUM(CASE WHEN s.mes_seg = 9  THEN s.cantidad ELSE 0 END) AS M09,
    SUM(CASE WHEN s.mes_seg = 10 THEN s.cantidad ELSE 0 END) AS M10,
    SUM(CASE WHEN s.mes_seg = 11 THEN s.cantidad ELSE 0 END) AS M11,
    SUM(CASE WHEN s.mes_seg = 12 THEN s.cantidad ELSE 0 END) AS M12
INTO #seg_res
FROM #seg AS s
GROUP BY s.id_episodio;

/*================================ 4. DATOS DEL SEGUIMIENTO =============================*/
IF OBJECT_ID('tempdb..#nominal') IS NOT NULL DROP TABLE #nominal;
SELECT
    i.id_episodio, i.num_doc, i.metodo, i.tipo, i.fec_inicio, i.fec_fin_seg,
    i.renaes_inicio, i.id_genero, i.edad_inicio,
    p.meta_anual,
    p.tolerancia,
    r.n_entregas,
    r.unidades,
    r.fec_ultima,
    CASE WHEN p.dias_x_unidad IS NOT NULL
         THEN DATEADD(DAY, CONVERT(INT, CEILING(u.cantidad * p.dias_x_unidad)), r.fec_ultima)
    END                                                                         AS fec_proxima,
    CASE WHEN i.fec_fin_seg < @fec_corte THEN i.fec_fin_seg ELSE @fec_corte END AS fec_eval,
    c.metodo                                                                    AS metodo_nuevo,
    c.fecha                                                                     AS fec_cambio,
    r.M01, r.M02, r.M03, r.M04, r.M05, r.M06, r.M07, r.M08, r.M09, r.M10, r.M11, r.M12,
    STUFF((SELECT ', ' + CONVERT(VARCHAR(10), f.fecha, 103)
           FROM #seg AS f
           WHERE f.id_episodio = i.id_episodio
           ORDER BY f.fecha
           FOR XML PATH('')), 1, 2, '')                                         AS fechas_entrega
INTO #nominal
FROM #inicio AS i
INNER JOIN #metodo_param AS p ON p.metodo = i.metodo
INNER JOIN #seg_res      AS r ON r.id_episodio = i.id_episodio
INNER JOIN #seg          AS u ON u.id_episodio = i.id_episodio AND u.fecha = r.fec_ultima
OUTER APPLY (SELECT TOP 1 x.metodo, x.fecha
             FROM #entrega AS x
             WHERE x.num_doc = i.num_doc
               AND x.metodo <> i.metodo
               AND x.fecha >  r.fec_ultima
               AND x.fecha <= i.fec_fin_seg
             ORDER BY x.fecha) AS c;

/*============================ 5. NOMINAL CON ESTADO FINAL ==============================*/
IF OBJECT_ID('tempdb..#reporte') IS NOT NULL DROP TABLE #reporte;
SELECT
    n.*,
    CASE WHEN n.fec_fin_seg <= @fec_corte THEN 'CERRADO (12 meses cumplidos)' ELSE 'ABIERTO' END AS seguimiento,
    CASE WHEN n.unidades >= n.meta_anual THEN 100 ELSE n.unidades * 100 / n.meta_anual END       AS avance_pct,
    CASE WHEN n.fec_proxima < n.fec_eval THEN DATEDIFF(DAY, n.fec_proxima, n.fec_eval) ELSE 0 END AS dias_atraso,
    CASE
        WHEN n.tipo = 'LARGO'                THEN 'PROTEGIDO - LARGA DURACION'
        WHEN n.tipo = 'DEFINITIVO'           THEN 'PROTEGIDO - DEFINITIVO'
        WHEN n.unidades >= n.meta_anual      THEN 'COMPLETO'
        WHEN n.fec_eval > DATEADD(DAY, n.tolerancia, n.fec_proxima)
             AND n.metodo_nuevo IS NOT NULL  THEN 'CAMBIO DE METODO'
        WHEN n.fec_eval > DATEADD(DAY, n.tolerancia, n.fec_proxima)
                                             THEN 'ABANDONO'
        WHEN n.fec_fin_seg > @fec_corte AND @fec_corte > n.fec_proxima
                                             THEN 'EN SEGUIMIENTO - CITA VENCIDA'
        WHEN n.fec_fin_seg > @fec_corte      THEN 'EN SEGUIMIENTO - AL DIA'
        ELSE 'INCOMPLETO'
    END                                                                                          AS estado
INTO #reporte
FROM #nominal AS n;

/* NOMINAL (una fila por persona y metodo iniciado) */
SELECT
    e.Descripcion_MicroRed     AS MicroRed,
    r.renaes_inicio            AS Renaes,
    e.Nombre_Establecimiento   AS Establecimiento,
    r.num_doc                  AS DNI,
    r.id_genero                AS Sexo,
    r.edad_inicio              AS Edad_inicio,
    r.metodo                   AS Metodo,
    r.fec_inicio               AS Fecha_inicio,
    r.fec_fin_seg              AS Fin_seguimiento,
    r.seguimiento              AS Seguimiento,
    r.meta_anual               AS Meta_anual,
    r.n_entregas               AS Entregas,
    r.unidades                 AS Unidades,
    r.avance_pct               AS Avance_pct,
    r.fec_ultima               AS Ultima_entrega,
    r.fec_proxima              AS Proxima_cita,
    r.dias_atraso              AS Dias_atraso,
    r.estado                   AS Estado,
    r.metodo_nuevo             AS Cambio_a,
    r.fec_cambio               AS Fecha_cambio,
    r.M01, r.M02, r.M03, r.M04, r.M05, r.M06, r.M07, r.M08, r.M09, r.M10, r.M11, r.M12,
    r.fechas_entrega           AS Fechas_entrega
FROM #reporte AS r
LEFT JOIN cgsalud2025.dbo.establecimiento AS e
       ON TRY_CONVERT(INT, e.Codigo_Unico) = TRY_CONVERT(INT, r.renaes_inicio)
ORDER BY r.metodo, r.fec_inicio, r.num_doc;
