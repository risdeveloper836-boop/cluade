/*===========================================================================================
  PLANIFICACION FAMILIAR: NOMINAL DE USUARIOS NUEVOS Y SU SEGUIMIENTO A 12 MESES

  Cohorte : personas (DNI) que INICIAN un metodo anticonceptivo moderno desde el 01/01/2025.
  Entrega : igual que el script original del indicador N 13: codigo del metodo con
            Tipo_Diagnostico D o R, en una cita que tiene 99208 con valor_lab = 'TA'.
            Vale para el inicio, para cada entrega y para el ultimo metodo.
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
  Validez : cada entrega tiene una fecha programada = entrega anterior + dias que protege lo
            entregado (trimestral 90 dias, mensual 28, oral 28 por ciclo, condon 30...). La entrega es
            VALIDA si se hizo dentro de +/- 5 dias de esa fecha; si no, NO VALIDA (ADELANTADA
            o TARDIA). Solo las unidades validas cuentan para COMPLETO.
  Ultimo  : ultimo metodo recibido por la persona hasta la fecha de corte (cualquier metodo).
  Salida  : UNA sola tabla: una fila por persona y metodo, con las entregas en columnas
            (E1 = inicio ... E13). Para cada entrega: fecha programada, fecha real, validez
            y registro HIS (Tipo_Diagnostico/Codigo_Item/valor_lab).
            Compatible con SQL Server 2012 o superior.
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
DECLARE @tol_valida  INT;

SET @ini_cohorte = '20250101';                 /* primer inicio a considerar             */
SET @fin_cohorte = '20261231';                 /* ultimo inicio a considerar             */
SET @fec_corte   = CONVERT(DATE, GETDATE());   /* fecha de corte de la informacion       */
SET @dias_nuevo  = 365;                        /* dias sin el metodo para ser NUEVO      */
SET @dias_seg    = 365;                        /* duracion del seguimiento               */
SET @edad_min    = 15;
SET @edad_max    = 49;
SET @tol_valida  = 5;                          /* +/- dias para que la entrega sea VALIDA */

/*================================ CATALOGO DE METODOS =================================
  meta_anual    : unidades que dan 1 anio de proteccion (inyectable trimestral = 4 dosis).
  dias_x_unidad : dias que protege cada unidad entregada (para calcular la proxima cita).
  tolerancia    : dias de gracia despues de la proxima cita antes de considerar ABANDONO.
  usa_cantidad  : 1 = la proteccion depende de la cantidad registrada en valor_lab (ciclos
                  del oral); 0 = cada entrega cuenta como 1 (inyectables, condones: mensual).
=======================================================================================*/
IF OBJECT_ID('tempdb..#metodo') IS NOT NULL DROP TABLE #metodo;
CREATE TABLE #metodo(
    cod_item      VARCHAR(10) PRIMARY KEY,
    metodo        VARCHAR(40),
    tipo          VARCHAR(12),
    meta_anual    INT,
    dias_x_unidad DECIMAL(6,2),
    tolerancia    INT,
    usa_cantidad  BIT
);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('99208.05', 'INYECTABLE TRIMESTRAL', 'CORTO', 4, 90.00, 30, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('99208.04', 'INYECTABLE MENSUAL', 'CORTO', 13, 28.00, 7, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('99208.13', 'ORAL COMBINADO', 'CORTO', 13, 28.00, 7, 1);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('99208.02', 'CONDON MASCULINO', 'CORTO', 12, 30.00, 7, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('99208.06', 'CONDON FEMENINO', 'CORTO', 12, 30.00, 7, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('58300', 'DIU', 'LARGO', 1, NULL, NULL, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('58300.01', 'SIU', 'LARGO', 1, NULL, NULL, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('11975', 'IMPLANTE', 'LARGO', 1, NULL, NULL, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('58600', 'LIGADURA DE TROMPAS', 'DEFINITIVO', 1, NULL, NULL, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('58605', 'LIGADURA DE TROMPAS', 'DEFINITIVO', 1, NULL, NULL, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('58611', 'LIGADURA DE TROMPAS', 'DEFINITIVO', 1, NULL, NULL, 0);
INSERT INTO #metodo (cod_item, metodo, tipo, meta_anual, dias_x_unidad, tolerancia, usa_cantidad) VALUES ('55250', 'VASECTOMIA', 'DEFINITIVO', 1, NULL, NULL, 0);

/* Un registro por metodo (la ligadura tiene 3 codigos) */
IF OBJECT_ID('tempdb..#metodo_param') IS NOT NULL DROP TABLE #metodo_param;
SELECT DISTINCT metodo, tipo, meta_anual, dias_x_unidad, tolerancia
INTO #metodo_param
FROM #metodo;

/*============================ 1. ENTREGAS DE METODOS (HIS) ============================
  Se lee desde el anio anterior al inicio de la cohorte para saber quien es NUEVO en enero.
  Una fila por persona + metodo + dia.
  Solo entregas validas segun el script original: Tipo_Diagnostico D o R y la cita debe tener
  99208 con valor_lab = 'TA'.
  cantidad: oral = ciclos registrados en valor_lab (vacio o no numerico = 1); los demas = 1.
=======================================================================================*/
IF OBJECT_ID('tempdb..#ent_det') IS NOT NULL DROP TABLE #ent_det;
SELECT
    h.Numero_Documento_Paciente                                    AS num_doc,
    m.metodo                                                       AS metodo,
    m.tipo                                                         AS tipo,
    CONVERT(DATE, h.Fecha_Atencion)                                AS fecha,
    h.Codigo_Unico                                                 AS renaes,
    h.id_genero                                                    AS id_genero,
    CASE WHEN h.Tipo_Edad = 'A' THEN h.edad_reg END                AS edad,
    CASE WHEN m.usa_cantidad = 1
         THEN ISNULL(NULLIF(TRY_CONVERT(INT, h.valor_lab), 0), 1)
         ELSE 1 END                                                AS cantidad,
    ISNULL(h.Tipo_Diagnostico, '') + '/' + ISNULL(h.Codigo_Item, '') + '/'
      + ISNULL(h.valor_lab, '')                                    AS registro
INTO #ent_det
FROM BDHIS_MINSA.dbo.DATA_HIS AS h WITH (NOLOCK)
INNER JOIN #metodo AS m ON m.cod_item = h.Codigo_Item
WHERE h.anio BETWEEN YEAR(@ini_cohorte) - 1 AND YEAR(@fec_corte)
  AND h.Tipo_Doc_Paciente = 1
  AND h.Tipo_Diagnostico IN ('D', 'R')
  AND CONVERT(DATE, h.Fecha_Atencion) <= @fec_corte
  AND EXISTS (SELECT 1
              FROM BDHIS_MINSA.dbo.DATA_HIS AS ta WITH (NOLOCK)
              WHERE ta.id_cita     = h.id_cita
                AND ta.anio        = h.anio
                AND ta.Codigo_Item = '99208'
                AND ta.valor_lab   = 'TA');

CREATE CLUSTERED INDEX ix_det ON #ent_det (num_doc, metodo, fecha);

/* registro: Tipo_Diagnostico/Codigo_Item/valor_lab de la entrega; si ese dia hay varios
   registros del mismo metodo se listan separados por coma (ej. D/99208.05/1, R/99208.05/) */
IF OBJECT_ID('tempdb..#entrega') IS NOT NULL DROP TABLE #entrega;
SELECT
    d.num_doc,
    d.metodo,
    d.tipo,
    d.fecha,
    MAX(d.renaes)                                                  AS renaes,
    MAX(d.id_genero)                                               AS id_genero,
    MAX(d.edad)                                                    AS edad,
    MAX(d.cantidad)                                                AS cantidad,
    STUFF((SELECT DISTINCT ', ' + d2.registro
           FROM #ent_det AS d2
           WHERE d2.num_doc = d.num_doc
             AND d2.metodo  = d.metodo
             AND d2.fecha   = d.fecha
           FOR XML PATH('')), 1, 2, '')                         AS registro
INTO #entrega
FROM #ent_det AS d
GROUP BY d.num_doc, d.metodo, d.tipo, d.fecha;

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
IF OBJECT_ID('tempdb..#seg0') IS NOT NULL DROP TABLE #seg0;
SELECT
    i.id_episodio,
    e.fecha,
    e.cantidad,
    e.renaes,
    e.registro,
    DATEDIFF(DAY, i.fec_inicio, e.fecha) * 12 / @dias_seg + 1                  AS mes_seg,
    ROW_NUMBER() OVER (PARTITION BY i.id_episodio ORDER BY e.fecha)             AS n_entrega,
    LAG(e.fecha)    OVER (PARTITION BY i.id_episodio ORDER BY e.fecha)          AS fec_prev,
    LAG(e.cantidad) OVER (PARTITION BY i.id_episodio ORDER BY e.fecha)          AS cant_prev
INTO #seg0
FROM #inicio AS i
INNER JOIN #entrega AS e
        ON e.num_doc = i.num_doc
       AND e.metodo  = i.metodo
       AND e.fecha BETWEEN i.fec_inicio AND i.fec_fin_seg;

/* Fecha programada y validez de cada entrega (+/- @tol_valida dias) */
IF OBJECT_ID('tempdb..#seg') IS NOT NULL DROP TABLE #seg;
SELECT
    a.*,
    b.fec_programada,
    DATEDIFF(DAY, b.fec_programada, a.fecha)                                    AS dif_dias,
    CASE
        WHEN a.n_entrega = 1                                          THEN 'INICIO'
        WHEN b.fec_programada IS NULL                                 THEN 'NO APLICA'
        WHEN ABS(DATEDIFF(DAY, b.fec_programada, a.fecha)) <= @tol_valida THEN 'VALIDA'
        WHEN a.fecha < b.fec_programada                               THEN 'NO VALIDA - ADELANTADA'
        ELSE 'NO VALIDA - TARDIA'
    END                                                                         AS validez,
    CASE
        WHEN a.n_entrega = 1 OR b.fec_programada IS NULL              THEN NULL
        WHEN ABS(DATEDIFF(DAY, b.fec_programada, a.fecha)) <= @tol_valida THEN 'VALIDA'
        ELSE 'NO VALIDA'
    END
    + CASE WHEN b.fec_programada IS NULL THEN '' ELSE
      ' (' + CASE WHEN DATEDIFF(DAY, b.fec_programada, a.fecha) > 0 THEN '+' ELSE '' END
           + CONVERT(VARCHAR(5), DATEDIFF(DAY, b.fec_programada, a.fecha)) + 'd)' END AS val_txt
INTO #seg
FROM #seg0 AS a
INNER JOIN #inicio       AS i ON i.id_episodio = a.id_episodio
INNER JOIN #metodo_param AS p ON p.metodo = i.metodo
CROSS APPLY (SELECT CASE WHEN a.fec_prev IS NOT NULL AND p.dias_x_unidad IS NOT NULL
                         THEN DATEADD(DAY, CONVERT(INT, CEILING(a.cant_prev * p.dias_x_unidad)), a.fec_prev)
                    END AS fec_programada) AS b;

IF OBJECT_ID('tempdb..#seg_res') IS NOT NULL DROP TABLE #seg_res;
SELECT
    s.id_episodio,
    COUNT(*)                                                 AS n_entregas,
    SUM(s.cantidad)                                          AS unidades,
    SUM(CASE WHEN s.validez IN ('INICIO','VALIDA') THEN 1 ELSE 0 END)          AS entregas_validas,
    SUM(CASE WHEN s.validez IN ('INICIO','VALIDA') THEN s.cantidad ELSE 0 END) AS unidades_validas,
    MAX(s.fecha)                                             AS fec_ultima,
    MAX(CASE WHEN s.n_entrega = 1 THEN s.fecha END) AS E1_Fecha,
    MAX(CASE WHEN s.n_entrega = 1 THEN s.registro END) AS E1_Registro,
    MAX(CASE WHEN s.n_entrega = 2 THEN s.fec_programada END) AS E2_Programada,
    MAX(CASE WHEN s.n_entrega = 2 THEN s.fecha END) AS E2_Fecha,
    MAX(CASE WHEN s.n_entrega = 2 THEN s.val_txt END) AS E2_Validez,
    MAX(CASE WHEN s.n_entrega = 2 THEN s.registro END) AS E2_Registro,
    MAX(CASE WHEN s.n_entrega = 3 THEN s.fec_programada END) AS E3_Programada,
    MAX(CASE WHEN s.n_entrega = 3 THEN s.fecha END) AS E3_Fecha,
    MAX(CASE WHEN s.n_entrega = 3 THEN s.val_txt END) AS E3_Validez,
    MAX(CASE WHEN s.n_entrega = 3 THEN s.registro END) AS E3_Registro,
    MAX(CASE WHEN s.n_entrega = 4 THEN s.fec_programada END) AS E4_Programada,
    MAX(CASE WHEN s.n_entrega = 4 THEN s.fecha END) AS E4_Fecha,
    MAX(CASE WHEN s.n_entrega = 4 THEN s.val_txt END) AS E4_Validez,
    MAX(CASE WHEN s.n_entrega = 4 THEN s.registro END) AS E4_Registro,
    MAX(CASE WHEN s.n_entrega = 5 THEN s.fec_programada END) AS E5_Programada,
    MAX(CASE WHEN s.n_entrega = 5 THEN s.fecha END) AS E5_Fecha,
    MAX(CASE WHEN s.n_entrega = 5 THEN s.val_txt END) AS E5_Validez,
    MAX(CASE WHEN s.n_entrega = 5 THEN s.registro END) AS E5_Registro,
    MAX(CASE WHEN s.n_entrega = 6 THEN s.fec_programada END) AS E6_Programada,
    MAX(CASE WHEN s.n_entrega = 6 THEN s.fecha END) AS E6_Fecha,
    MAX(CASE WHEN s.n_entrega = 6 THEN s.val_txt END) AS E6_Validez,
    MAX(CASE WHEN s.n_entrega = 6 THEN s.registro END) AS E6_Registro,
    MAX(CASE WHEN s.n_entrega = 7 THEN s.fec_programada END) AS E7_Programada,
    MAX(CASE WHEN s.n_entrega = 7 THEN s.fecha END) AS E7_Fecha,
    MAX(CASE WHEN s.n_entrega = 7 THEN s.val_txt END) AS E7_Validez,
    MAX(CASE WHEN s.n_entrega = 7 THEN s.registro END) AS E7_Registro,
    MAX(CASE WHEN s.n_entrega = 8 THEN s.fec_programada END) AS E8_Programada,
    MAX(CASE WHEN s.n_entrega = 8 THEN s.fecha END) AS E8_Fecha,
    MAX(CASE WHEN s.n_entrega = 8 THEN s.val_txt END) AS E8_Validez,
    MAX(CASE WHEN s.n_entrega = 8 THEN s.registro END) AS E8_Registro,
    MAX(CASE WHEN s.n_entrega = 9 THEN s.fec_programada END) AS E9_Programada,
    MAX(CASE WHEN s.n_entrega = 9 THEN s.fecha END) AS E9_Fecha,
    MAX(CASE WHEN s.n_entrega = 9 THEN s.val_txt END) AS E9_Validez,
    MAX(CASE WHEN s.n_entrega = 9 THEN s.registro END) AS E9_Registro,
    MAX(CASE WHEN s.n_entrega = 10 THEN s.fec_programada END) AS E10_Programada,
    MAX(CASE WHEN s.n_entrega = 10 THEN s.fecha END) AS E10_Fecha,
    MAX(CASE WHEN s.n_entrega = 10 THEN s.val_txt END) AS E10_Validez,
    MAX(CASE WHEN s.n_entrega = 10 THEN s.registro END) AS E10_Registro,
    MAX(CASE WHEN s.n_entrega = 11 THEN s.fec_programada END) AS E11_Programada,
    MAX(CASE WHEN s.n_entrega = 11 THEN s.fecha END) AS E11_Fecha,
    MAX(CASE WHEN s.n_entrega = 11 THEN s.val_txt END) AS E11_Validez,
    MAX(CASE WHEN s.n_entrega = 11 THEN s.registro END) AS E11_Registro,
    MAX(CASE WHEN s.n_entrega = 12 THEN s.fec_programada END) AS E12_Programada,
    MAX(CASE WHEN s.n_entrega = 12 THEN s.fecha END) AS E12_Fecha,
    MAX(CASE WHEN s.n_entrega = 12 THEN s.val_txt END) AS E12_Validez,
    MAX(CASE WHEN s.n_entrega = 12 THEN s.registro END) AS E12_Registro,
    MAX(CASE WHEN s.n_entrega = 13 THEN s.fec_programada END) AS E13_Programada,
    MAX(CASE WHEN s.n_entrega = 13 THEN s.fecha END) AS E13_Fecha,
    MAX(CASE WHEN s.n_entrega = 13 THEN s.val_txt END) AS E13_Validez,
    MAX(CASE WHEN s.n_entrega = 13 THEN s.registro END) AS E13_Registro
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
    r.entregas_validas,
    r.unidades_validas,
    r.fec_ultima,
    CASE WHEN p.dias_x_unidad IS NOT NULL
         THEN DATEADD(DAY, CONVERT(INT, CEILING(u.cantidad * p.dias_x_unidad)), r.fec_ultima)
    END                                                                         AS fec_proxima,
    CASE WHEN i.fec_fin_seg < @fec_corte THEN i.fec_fin_seg ELSE @fec_corte END AS fec_eval,
    c.metodo                                                                    AS metodo_nuevo,
    c.fecha                                                                     AS fec_cambio,
    ul.metodo                                                                   AS ultimo_metodo,
    ul.fecha                                                                    AS fec_ultimo_metodo,
    r.E1_Fecha, r.E1_Registro,
    r.E2_Programada, r.E2_Fecha, r.E2_Validez, r.E2_Registro,
    r.E3_Programada, r.E3_Fecha, r.E3_Validez, r.E3_Registro,
    r.E4_Programada, r.E4_Fecha, r.E4_Validez, r.E4_Registro,
    r.E5_Programada, r.E5_Fecha, r.E5_Validez, r.E5_Registro,
    r.E6_Programada, r.E6_Fecha, r.E6_Validez, r.E6_Registro,
    r.E7_Programada, r.E7_Fecha, r.E7_Validez, r.E7_Registro,
    r.E8_Programada, r.E8_Fecha, r.E8_Validez, r.E8_Registro,
    r.E9_Programada, r.E9_Fecha, r.E9_Validez, r.E9_Registro,
    r.E10_Programada, r.E10_Fecha, r.E10_Validez, r.E10_Registro,
    r.E11_Programada, r.E11_Fecha, r.E11_Validez, r.E11_Registro,
    r.E12_Programada, r.E12_Fecha, r.E12_Validez, r.E12_Registro,
    r.E13_Programada, r.E13_Fecha, r.E13_Validez, r.E13_Registro
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
             ORDER BY x.fecha) AS c
OUTER APPLY (SELECT TOP 1 y.metodo, y.fecha
             FROM #entrega AS y
             WHERE y.num_doc = i.num_doc
             ORDER BY y.fecha DESC, y.metodo) AS ul;

/*============================ 5. NOMINAL CON ESTADO FINAL ==============================*/
IF OBJECT_ID('tempdb..#reporte') IS NOT NULL DROP TABLE #reporte;
SELECT
    n.*,
    CASE WHEN n.fec_fin_seg <= @fec_corte THEN 'CERRADO (12 meses cumplidos)' ELSE 'ABIERTO' END AS seguimiento,
    CASE WHEN n.unidades_validas >= n.meta_anual THEN 100 ELSE n.unidades_validas * 100 / n.meta_anual END AS avance_pct,
    CASE WHEN n.fec_proxima < n.fec_eval THEN DATEDIFF(DAY, n.fec_proxima, n.fec_eval) ELSE 0 END AS dias_atraso,
    CASE
        WHEN n.tipo = 'LARGO'                THEN 'PROTEGIDO - LARGA DURACION'
        WHEN n.tipo = 'DEFINITIVO'           THEN 'PROTEGIDO - DEFINITIVO'
        WHEN n.unidades_validas >= n.meta_anual THEN 'COMPLETO'
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

/* NOMINAL: una fila por persona y metodo iniciado, con sus entregas en columnas */
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
    r.entregas_validas         AS Entregas_validas,
    r.unidades_validas         AS Unidades_validas,
    r.avance_pct               AS Avance_pct,
    r.fec_ultima               AS Ultima_entrega,
    r.fec_proxima              AS Proxima_cita,
    r.dias_atraso              AS Dias_atraso,
    r.estado                   AS Estado,
    r.metodo_nuevo             AS Cambio_a,
    r.fec_cambio               AS Fecha_cambio,
    r.ultimo_metodo            AS Ultimo_metodo,
    r.fec_ultimo_metodo        AS Fecha_ultimo_metodo,
    r.E1_Fecha, r.E1_Registro,
    r.E2_Programada, r.E2_Fecha, r.E2_Validez, r.E2_Registro,
    r.E3_Programada, r.E3_Fecha, r.E3_Validez, r.E3_Registro,
    r.E4_Programada, r.E4_Fecha, r.E4_Validez, r.E4_Registro,
    r.E5_Programada, r.E5_Fecha, r.E5_Validez, r.E5_Registro,
    r.E6_Programada, r.E6_Fecha, r.E6_Validez, r.E6_Registro,
    r.E7_Programada, r.E7_Fecha, r.E7_Validez, r.E7_Registro,
    r.E8_Programada, r.E8_Fecha, r.E8_Validez, r.E8_Registro,
    r.E9_Programada, r.E9_Fecha, r.E9_Validez, r.E9_Registro,
    r.E10_Programada, r.E10_Fecha, r.E10_Validez, r.E10_Registro,
    r.E11_Programada, r.E11_Fecha, r.E11_Validez, r.E11_Registro,
    r.E12_Programada, r.E12_Fecha, r.E12_Validez, r.E12_Registro,
    r.E13_Programada, r.E13_Fecha, r.E13_Validez, r.E13_Registro
FROM #reporte AS r
LEFT JOIN cgsalud2025.dbo.establecimiento AS e
       ON TRY_CONVERT(INT, e.Codigo_Unico) = TRY_CONVERT(INT, r.renaes_inicio)
ORDER BY r.metodo, r.fec_inicio, r.num_doc;
