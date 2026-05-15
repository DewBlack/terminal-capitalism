# News Generation Quality Report

## Configuracion
- Timestamp (UTC): `2026-05-15 18:04:01`
- Output: `res://reports/news_generation_quality_report.md`
- Args: ``
- Runs: `10`
- Dias por run: `30`
- Seed base: `17031`
- Empresas iniciales: `9`

## Resumen
| Metrica | Valor |
| --- | --- |
| Noticias analizadas | 543 |
| Placeholders sin resolver | 0 |
| Texto vacio | 0 |
| Titulos cortos | 0 |
| Descripciones cortas | 0 |
| Repeticion patologica | 0 |
| Trazabilidad ticker | 543 (100.0%) |
| Trazabilidad con impacto | 540 (99.4%) |
| Senal ALCISTA | 296 |
| Senal BAJISTA | 238 |
| Senal MIXTA | 6 |
| Senal NEUTRA | 0 |
| Senal SIN_IMPACTO | 3 |
| Senal ambigua | 10 (1.8%) |
| Ratio titulos repetidos | 44.2% |

## Checks
| Check | Tipo | Regla | Actual | Estado |
| --- | --- | --- | --- | --- |
| `placeholders_unresolved` | required | <= 0.000 | 0.000 | PASS |
| `empty_text` | required | <= 0.000 | 0.000 | PASS |
| `short_title` | required | <= 0.000 | 0.000 | PASS |
| `short_description` | required | <= 0.000 | 0.000 | PASS |
| `pathological_repetition` | required | <= 0.000 | 0.000 | PASS |
| `traceability_ratio` | required | >= 0.920 | 1.000 | PASS |
| `impact_link_ratio` | required | >= 0.780 | 0.994 | PASS |
| `duplicate_title_ratio` | advisory | <= 0.260 | 0.442 | FAIL |
| `ambiguous_signal_ratio` | advisory | <= 0.520 | 0.018 | PASS |

## Umbrales
- `MIN_TITLE_LENGTH`: `12`
- `MIN_DESCRIPTION_LENGTH`: `34`
- `MIN_TRACE_RATIO`: `0.92`
- `MIN_IMPACT_RATIO`: `0.78`
- `MAX_DUPLICATE_TITLE_RATIO`: `0.26`
- `MAX_AMBIGUOUS_SIGNAL_RATIO`: `0.52`

## Noticias con Flags (Top 120)
- R03 D24 `SIN_IMPACTO` avg=0.00% | id=`satellite_delivery_loss` | flags=no_impact_link, ambiguous_signal
  - Titulo: Neo-Lemon Systems Finance: Se pierde satelite con paquetes premium
  - Descripcion: Impacta a Neo-Lemon Systems Finance (NEOL) y HyperLemon Tech (HLEM). Aseguradoras discuten si la orbita cuenta como almacen.
  - Tags+: finance | Tags-: space, transport, finance
  - Tickers trazados: NEOL, HLEM, DRFM | Tickers con impacto: 
- R09 D13 `SIN_IMPACTO` avg=0.00% | id=`satellite_delivery_loss` | flags=no_impact_link, ambiguous_signal
  - Titulo: TurboCond Foods: Se pierde satelite con paquetes premium
  - Descripcion: Impacta a TurboCond Foods (TURB) y HyperLemon Tech (HLEM). Aseguradoras discuten si la orbita cuenta como almacen.
  - Tags+: finance | Tags-: space, transport, finance
  - Tickers trazados: TURB, HLEM, SOUP | Tickers con impacto: 
- R09 D19 `SIN_IMPACTO` avg=0.00% | id=`satellite_delivery_loss` | flags=no_impact_link, ambiguous_signal
  - Titulo: TurboCond Foods: Se pierde satelite con paquetes premium con riesgo reputacional creciente
  - Descripcion: Impacta a TurboCond Foods (TURB) y HyperLemon Tech (HLEM). Aseguradoras discuten si la orbita cuenta como almacen.
  - Tags+: finance | Tags-: space, transport, finance
  - Tickers trazados: TURB, HLEM, SOUP | Tickers con impacto: 
- R03 D01 `MIXTA` avg=-0.11% | id=`health_agency_trial` | flags=ambiguous_signal
  - Titulo: Proto-Volt Group Harvest: Agencia sanitaria abre ensayo acelerado
  - Descripcion: Impacta a Proto-Volt Group Harvest (PROT) y DreamFuel Pharma (DRFM). Farmaceuticas de energia ganan visibilidad y riesgo legal. Gestores ajustan coberturas y vigilan correlaciones del sector.
  - Tags+: pharma, hype | Tags-: legal_risk, scandal
  - Tickers trazados: PROT, DRFM, HLEM | Tickers con impacto: PROT, DRFM
- R03 D11 `MIXTA` avg=-0.11% | id=`health_agency_trial` | flags=ambiguous_signal
  - Titulo: Proto-Volt Group Harvest: Agencia sanitaria abre ensayo acelerado
  - Descripcion: Impacta a Proto-Volt Group Harvest (PROT) y DreamFuel Pharma (DRFM). Farmaceuticas de energia ganan visibilidad y riesgo legal. Gestores ajustan coberturas y vigilan correlaciones del sector.
  - Tags+: pharma, hype | Tags-: legal_risk, scandal
  - Tickers trazados: PROT, DRFM, MEGA | Tickers con impacto: PROT, DRFM
- R05 D01 `BAJISTA` avg=-0.76% | id=`babyvolt_toaster_rebellion` | flags=ambiguous_signal
  - Titulo: Tostadoras de BabyVolt exigen vacaciones
  - Descripcion: BabyVolt enfrenta caos operativo por caos operativo en el sector energy. La narrativa absurda reordena expectativas en torno a energy.
  - Tags+: energy, family | Tags-: chaos, regulation
  - Tickers trazados: BBVT, QUAN, DRFM | Tickers con impacto: BBVT, QUAN, DRFM
- R10 D12 `MIXTA` avg=0.23% | id=`grimburger_not_furniture` | flags=ambiguous_signal
  - Titulo: NanoPixel Nebula Interlink Harvest aclara que sus productos no son muebles
  - Descripcion: La regulacion golpea a NanoPixel Nebula Interlink Harvest por temas de escandalo y etiquetas confusas. La plaza traduce el titular en revisiones de riesgo regulatorio.
  - Tags+: fast_food, meme | Tags-: legal_risk, regulation, scandal
  - Tickers trazados: NANO, COSM, ORSP | Tickers con impacto: NANO, COSM, ORSP
- R10 D17 `MIXTA` avg=0.23% | id=`grimburger_not_furniture` | flags=ambiguous_signal
  - Titulo: NanoPixel Nebula Interlink Harvest aclara que sus productos no son muebles bajo lupa normativa
  - Descripcion: La regulacion golpea a NanoPixel Nebula Interlink Harvest por temas de regulacion y etiquetas confusas. La plaza traduce el titular en revisiones de riesgo regulatorio.
  - Tags+: fast_food, meme | Tags-: legal_risk, regulation, scandal
  - Tickers trazados: NANO, COSM, ORSP | Tickers con impacto: NANO, COSM, ORSP
- R10 D22 `MIXTA` avg=0.23% | id=`grimburger_not_furniture` | flags=ambiguous_signal
  - Titulo: NanoPixel Nebula Interlink Harvest aclara que sus productos no son muebles bajo lupa normativa
  - Descripcion: La regulacion golpea a NanoPixel Nebula Interlink Harvest por temas de riesgo legal y etiquetas confusas.
  - Tags+: fast_food, meme | Tags-: legal_risk, regulation, scandal
  - Tickers trazados: NANO, COSM, ORSP | Tickers con impacto: NANO, COSM, ORSP
- R10 D29 `MIXTA` avg=0.23% | id=`grimburger_not_furniture` | flags=ambiguous_signal
  - Titulo: NanoPixel Nebula Interlink Harvest aclara que sus productos no son muebles tras nueva circular
  - Descripcion: La regulacion golpea a NanoPixel Nebula Interlink Harvest por temas de riesgo legal y etiquetas confusas.
  - Tags+: fast_food, meme | Tags-: legal_risk, regulation, scandal
  - Tickers trazados: NANO, COSM, ORSP | Tickers con impacto: NANO, COSM, ORSP

## Volcado de Noticias (Top 240)
| Run | Dia | Senal | AvgImpact | Flags | Titulo | Tickers impacto |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | BAJISTA | -8.50% |  | Orbit Syndicate: Varias companias anuncian reverse split de emergencia | ORBI, FACT, ORSP |
| 1 | 1 | BAJISTA | -14.66% |  | GrimBurger aclara que sus productos no son muebles | GRMB, FACT, QUAN |
| 1 | 2 | BAJISTA | -11.70% |  | DreamCond Factory Mutual: Prohibicion temporal de exportar chips cuanticos | DREA, ORBI, FACT |
| 1 | 2 | ALCISTA | 15.28% |  | Factory Crate Holdings enfria servidores con una vaca estrategica | FACT, MOOM, DREA |
| 1 | 2 | BAJISTA | -11.86% |  | GrimBurger: Ex directivo filtra chat interno comprometedor | GRMB, FACT, ORSP |
| 1 | 3 | BAJISTA | -10.62% |  | Orbit Syndicate despide a su IA por comprar limones | ORBI, FACT, DREA |
| 1 | 4 | ALCISTA | 12.98% |  | DreamCond Factory Mutual: Patente para granjas cuanticas de microchips lacteos | DREA, QUAN, ORBI |
| 1 | 4 | BAJISTA | -20.00% |  | Orbital Soup: Se pierde satelite con paquetes premium | ORSP |
| 1 | 5 | ALCISTA | 3.58% |  | GrimBurger: Agencia sanitaria abre ensayo acelerado segun operadores | GRMB, ORSP, DREA |
| 1 | 5 | BAJISTA | -14.66% |  | GrimBurger aclara que sus productos no son muebles | GRMB, FACT, QUAN |
| 1 | 6 | BAJISTA | -14.33% |  | Factory Crate Holdings: Auditoria automatica detecta clausulas explosivas | FACT, GRMB, ORBI |
| 1 | 6 | BAJISTA | -9.07% |  | HyperFuel Holdings: Sindicatos de palomas convocan paro general en plena tension reputacional | HYPE, ORBI, FACT |
| 1 | 7 | ALCISTA | 10.36% |  | Factory Crate Holdings: Oleada de rumores de fusiones imposibles | FACT, GRMB, ORSP |
| 1 | 7 | ALCISTA | 12.98% |  | DreamCond Factory Mutual: Patente para granjas cuanticas de microchips lacteos | DREA, QUAN, ORBI |
| 1 | 8 | BAJISTA | -10.62% |  | Orbit Syndicate: Hilo viral denuncia promesas infladas en plena tension reputacional | ORBI, FACT, ORSP |
| 1 | 8 | ALCISTA | 9.14% |  | GrimBurger: Fondo familiar entra fuerte en consumo domestico | GRMB, BBVT, ORBI |
| 1 | 9 | ALCISTA | 18.61% |  | Orbital Soup: Nueva startup de comida espacial sale a bolsa | ORSP, QUAN, GRMB |
| 1 | 9 | ALCISTA | 9.81% |  | Orbital Soup pone una lata en orbita baja | ORSP, ORBI, FACT |
| 1 | 10 | BAJISTA | -9.46% |  | Tostadoras de BabyVolt exigen vacaciones entre apuestas de alto ruido | BBVT, ORBI, HYPE |
| 1 | 10 | ALCISTA | 13.58% |  | Heladera de leche inteligente reduce facturas | BBVT, FACT, MOOM |
| 1 | 11 | ALCISTA | 8.76% |  | Orbit Syndicate: Sindicato de IA publica manifiesto anti-limon | ORBI, FACT, DREA |
| 1 | 12 | ALCISTA | 17.34% |  | Orbit Syndicate abre mercado de huertos con drones vaqueros | ORBI, MOOM, QUAN |
| 1 | 12 | ALCISTA | 5.95% |  | Orbit Syndicate: Bateria de queso supera prueba de 48 horas | ORBI, FACT, HYPE |
| 1 | 13 | BAJISTA | -9.07% |  | HyperFuel Holdings: Sindicatos de palomas convocan paro general | HYPE, ORBI, FACT |
| 1 | 14 | ALCISTA | 15.28% |  | Factory Crate Holdings enfria servidores con una vaca estrategica | FACT, MOOM, DREA |
| 1 | 14 | BAJISTA | -14.66% |  | GrimBurger aclara que sus productos no son muebles | GRMB, FACT, QUAN |
| 1 | 15 | BAJISTA | -9.46% |  | Tostadoras de Orbit Syndicate exigen vacaciones | ORBI, BBVT, HYPE |
| 1 | 16 | ALCISTA | 15.68% |  | Nueva receta de Orbital Soup con polvo meteoritico | GRMB, ORSP, QUAN |
| 1 | 17 | BAJISTA | -9.07% |  | HyperFuel Holdings: Sindicatos de palomas convocan paro general | HYPE, ORBI, FACT |
| 1 | 17 | ALCISTA | 16.04% |  | Orbital Soup: Foro nocturno elige nueva accion favorita | ORSP, DREA, ORBI |
| 1 | 18 | ALCISTA | 5.95% |  | Orbit Syndicate: Bateria de queso supera prueba de 48 horas | ORBI, FACT, HYPE |
| 1 | 18 | BAJISTA | -10.62% |  | Orbit Syndicate: Hilo viral denuncia promesas infladas | ORBI, FACT, ORSP |
| 1 | 19 | ALCISTA | 9.14% |  | GrimBurger: Fondo familiar entra fuerte en consumo domestico | GRMB, BBVT, ORBI |
| 1 | 19 | BAJISTA | -17.10% |  | GrimBurger: Boicot comunitario por marketing demasiado agresivo | GRMB, QUAN, ORSP |
| 1 | 20 | BAJISTA | -9.07% |  | HyperFuel Holdings: Sindicatos de palomas convocan paro general | HYPE, ORBI, FACT |
| 1 | 21 | ALCISTA | 13.31% |  | Orbital Soup firma contrato para comedores en estacion orbital | ORSP, GRMB, QUAN |
| 1 | 22 | BAJISTA | -10.62% |  | Orbit Syndicate despide a su IA por comprar limones con riesgo reputacional creciente | ORBI, FACT, DREA |
| 1 | 22 | ALCISTA | 8.76% |  | Orbit Syndicate: Sindicato de IA publica manifiesto anti-limon | ORBI, FACT, DREA |
| 1 | 23 | ALCISTA | 15.68% |  | Nueva receta de Orbital Soup con polvo meteoritico | GRMB, ORSP, QUAN |
| 1 | 23 | BAJISTA | -11.86% |  | GrimBurger: Ex directivo filtra chat interno comprometedor con riesgo reputacional creciente | GRMB, FACT, ORSP |
| 1 | 24 | BAJISTA | -11.77% |  | Crisis de montacargas golpea a HyperFuel Holdings | HYPE, ORSP, ORBI |
| 1 | 24 | BAJISTA | -10.62% |  | Orbit Syndicate: Hilo viral denuncia promesas infladas | ORBI, FACT, ORSP |
| 1 | 25 | BAJISTA | -20.00% |  | Factory Crate Holdings: El regulador avisa sobre acciones meme inestables | FACT, ORBI, GRMB |
| 1 | 26 | ALCISTA | 9.72% |  | HyperFuel Holdings anuncia envios interdimensionales | HYPE, ORSP, DREA |
| 1 | 26 | BAJISTA | -14.33% |  | Factory Crate Holdings: Auditoria automatica detecta clausulas explosivas | FACT, GRMB, ORBI |
| 1 | 27 | ALCISTA | 8.76% |  | Orbit Syndicate: Sindicato de IA publica manifiesto anti-limon | ORBI, FACT, DREA |
| 1 | 27 | ALCISTA | 15.42% |  | Orbit Syndicate: Subsidio estatal para energia domestica segun operadores | ORBI, FACT, BBVT |
| 1 | 28 | BAJISTA | -11.77% |  | Crisis de montacargas golpea a HyperFuel Holdings | HYPE, ORSP, ORBI |
| 1 | 28 | BAJISTA | -10.62% |  | Orbit Syndicate despide a su IA por comprar limones con riesgo reputacional creciente | ORBI, FACT, DREA |
| 1 | 29 | ALCISTA | 15.68% |  | Nueva receta de GrimBurger con polvo meteoritico | ORSP, GRMB, QUAN |
| 1 | 29 | BAJISTA | -11.70% |  | DreamCond Factory Mutual: Prohibicion temporal de exportar chips cuanticos | DREA, ORBI, FACT |
| 1 | 30 | ALCISTA | 13.31% |  | Orbital Soup firma contrato para comedores en estacion orbital | ORSP, GRMB, QUAN |
| 2 | 1 | BAJISTA | -16.05% |  | AstroFarm Foods Transit: El regulador avisa sobre acciones meme inestables | ASTR, DREA, HLEM |
| 2 | 1 | BAJISTA | -11.37% |  | HyperLemon Tech: Varias companias anuncian reverse split de emergencia segun operadores | HLEM, ASTR, DRFM |
| 2 | 2 | ALCISTA | 1.16% |  | AstroFarm Foods Transit: Semana de descuentos extremos en comida dudosa | GRMB, DREA |
| 2 | 2 | ALCISTA | 15.74% |  | HyperLemon Tech pone una lata en orbita baja | HLEM, ASTR, HYPE |
| 2 | 3 | BAJISTA | -1.80% |  | Crisis de montacargas golpea a DreamOrbit Holdings en plena tension reputacional | DREA, ASTR, HYPE |
| 2 | 3 | BAJISTA | -20.00% |  | AstroFarm Foods Transit aclara que sus productos no son muebles tras nueva circular | ASTR, GRMB, DREA |
| 2 | 3 | BAJISTA | -16.05% |  | AstroFarm Foods Transit: El regulador avisa sobre acciones meme inestables | ASTR, DREA, HLEM |
| 2 | 4 | ALCISTA | 11.00% |  | DreamOrbit Holdings abre mercado de huertos con drones vaqueros | DREA, ASTR, HLEM |
| 2 | 4 | ALCISTA | 19.52% |  | HyperLemon Tech: Foro nocturno elige nueva accion favorita y dispara foros | HLEM, ASTR, GRMB |
| 2 | 5 | ALCISTA | 18.69% |  | AstroFarm Foods Transit: Nueva startup de comida espacial sale a bolsa | ASTR, GRMB, HLEM |
| 2 | 5 | BAJISTA | -20.00% |  | AstroFarm Foods Transit: Ex directivo filtra chat interno comprometedor | ASTR, GRMB, DRFM |
| 2 | 6 | ALCISTA | 5.60% |  | HyperLemon Tech: Sindicato de IA publica manifiesto anti-limon | HLEM, ASTR, DREA |
| 2 | 7 | ALCISTA | 17.18% |  | DreamOrbit Holdings: Subsidio estatal para energia domestica en sesion de alta expectativa | DREA, ASTR, HYPE |
| 2 | 7 | ALCISTA | 16.44% |  | DreamOrbit Holdings: Heladera de leche inteligente reduce facturas segun operadores | DREA, ASTR, BBVT |
| 2 | 8 | ALCISTA | 5.60% |  | HyperLemon Tech: Sindicato de IA publica manifiesto anti-limon | HLEM, ASTR, DREA |
| 2 | 9 | BAJISTA | -11.62% |  | DreamOrbit Holdings: Prohibicion temporal de exportar chips cuanticos | DREA, SPCD, HYPE |
| 2 | 10 | BAJISTA | -7.72% |  | HyperMoo Foods: Tormenta geomagnetica bloquea rutas de transporte segun operadores | HYPE, DREA, DRFM |
| 2 | 10 | ALCISTA | 3.03% |  | GrimBurger firma contrato para comedores en estacion orbital | GRMB, ASTR, DREA |
| 2 | 10 | BAJISTA | -1.80% |  | Crisis de montacargas golpea a DreamOrbit Holdings | DREA, HYPE, ASTR |
| 2 | 11 | BAJISTA | -10.29% |  | HyperMoo Foods: Se pierde satelite con paquetes premium | HYPE |
| 2 | 11 | ALCISTA | 18.21% |  | AstroFarm Foods Transit: Oleada de rumores de fusiones imposibles con rally social inesperado | ASTR, HLEM, GRMB |
| 2 | 12 | ALCISTA | 8.71% |  | Nueva receta de AstroFarm Foods Transit con polvo meteoritico y dispara foros | GRMB, ASTR, KING |
| 2 | 12 | ALCISTA | 19.52% |  | HyperLemon Tech: Foro nocturno elige nueva accion favorita con rally social inesperado | HLEM, ASTR, GRMB |
| 2 | 13 | ALCISTA | 18.69% |  | AstroFarm Foods Transit: Nueva startup de comida espacial sale a bolsa y dispara foros | ASTR, GRMB, HLEM |
| 2 | 14 | BAJISTA | -11.37% |  | HyperLemon Tech: Varias companias anuncian reverse split de emergencia | HLEM, ASTR, DRFM |
| 2 | 14 | ALCISTA | 12.90% |  | DreamOrbit Holdings: Fondo familiar entra fuerte en consumo domestico | DREA, ASTR, GRMB |
| 2 | 15 | BAJISTA | -18.91% |  | AstroFarm Foods Transit: Auditoria automatica detecta clausulas explosivas tras nueva circular | ASTR, DREA, DRFM |
| 2 | 16 | BAJISTA | -3.97% |  | Tostadoras de DreamOrbit Holdings exigen vacaciones | BBVT |
| 2 | 16 | ALCISTA | 8.62% |  | SperCond: Bateria de queso supera prueba de 48 horas | SPCD, DREA, HYPE |
| 2 | 17 | ALCISTA | 19.52% |  | HyperLemon Tech: Foro nocturno elige nueva accion favorita | HLEM, ASTR, GRMB |
| 2 | 17 | BAJISTA | -18.91% |  | AstroFarm Foods Transit: Auditoria automatica detecta clausulas explosivas | ASTR, DREA, DRFM |
| 2 | 17 | BAJISTA | -1.80% |  | Crisis de montacargas golpea a DreamOrbit Holdings | DREA, HYPE, ASTR |
| 2 | 18 | BAJISTA | -20.00% |  | AstroFarm Foods Transit: Ex directivo filtra chat interno comprometedor | ASTR, GRMB, DRFM |
| 2 | 18 | ALCISTA | 17.18% |  | DreamOrbit Holdings: Subsidio estatal para energia domestica segun operadores | DREA, ASTR, HYPE |
| 2 | 19 | ALCISTA | 18.69% |  | AstroFarm Foods Transit: Nueva startup de comida espacial sale a bolsa | ASTR, GRMB, HLEM |
| 2 | 20 | BAJISTA | -20.00% |  | AstroFarm Foods Transit aclara que sus productos no son muebles | ASTR, GRMB, DREA |
| 2 | 20 | BAJISTA | -1.80% |  | Crisis de montacargas golpea a DreamOrbit Holdings en plena tension reputacional | DREA, HYPE, ASTR |
| 2 | 21 | BAJISTA | -1.80% |  | Crisis de montacargas golpea a DreamOrbit Holdings | DREA, HYPE, ASTR |
| 2 | 22 | ALCISTA | 1.16% |  | AstroFarm Foods Transit: Semana de descuentos extremos en comida dudosa segun operadores | DREA, GRMB |
| 2 | 22 | ALCISTA | 8.71% |  | Nueva receta de AstroFarm Foods Transit con polvo meteoritico | GRMB, ASTR, KING |
| 2 | 23 | BAJISTA | -20.00% |  | AstroFarm Foods Transit aclara que sus productos no son muebles tras nueva circular | ASTR, GRMB, DREA |
| 2 | 23 | BAJISTA | -3.97% |  | Tostadoras de DreamOrbit Holdings exigen vacaciones | BBVT |
| 2 | 24 | ALCISTA | 2.61% |  | HyperMoo Foods anuncia envios interdimensionales | HYPE, DREA, HLEM |
| 2 | 24 | BAJISTA | -18.91% |  | AstroFarm Foods Transit: Auditoria automatica detecta clausulas explosivas | ASTR, DREA, DRFM |
| 2 | 25 | ALCISTA | 11.00% |  | DreamOrbit Holdings abre mercado de huertos con drones vaqueros | DREA, ASTR, HLEM |
| 2 | 26 | BAJISTA | -14.91% |  | AstroFarm Foods Transit: Hilo viral denuncia promesas infladas | ASTR, HLEM, HYPE |
| 2 | 26 | BAJISTA | -11.56% |  | DreamOrbit Holdings: Prohibicion temporal de exportar chips cuanticos | DREA, SPCD, ASTR |
| 2 | 27 | BAJISTA | -7.72% |  | HyperMoo Foods: Tormenta geomagnetica bloquea rutas de transporte segun operadores | HYPE, DREA, DRFM |
| 2 | 28 | ALCISTA | 18.69% |  | AstroFarm Foods Transit: Nueva startup de comida espacial sale a bolsa | ASTR, GRMB, HLEM |
| 2 | 28 | ALCISTA | 15.74% |  | HyperLemon Tech pone una lata en orbita baja | HLEM, HYPE, ASTR |
| 2 | 29 | BAJISTA | -18.91% |  | AstroFarm Foods Transit: Auditoria automatica detecta clausulas explosivas bajo lupa normativa | ASTR, DREA, DRFM |
| 2 | 30 | ALCISTA | 3.03% |  | GrimBurger firma contrato para comedores en estacion orbital en sesion de alta expectativa | GRMB, ASTR, DREA |
| 3 | 1 | ALCISTA | 19.13% |  | HyperLemon Tech: Foro nocturno elige nueva accion favorita | HLEM, PROT, MEGA |
| 3 | 1 | MIXTA | -0.11% | ambiguous_signal | Proto-Volt Group Harvest: Agencia sanitaria abre ensayo acelerado | PROT, DRFM |
| 3 | 1 | ALCISTA | 8.60% |  | Proto-Volt Group Harvest promete superconductores de queso en sesion de alta expectativa | PROT, MEGA, HLEM |
| 3 | 2 | BAJISTA | -8.49% |  | HyperCrate Holdings Agro: Hilo viral denuncia promesas infladas | HYP1, HLEM, NEOL |
| 3 | 3 | ALCISTA | 12.28% |  | Proto-Volt Group Harvest: Patente para granjas cuanticas de microchips lacteos | PROT, MEGA, HYP1 |
| 3 | 3 | ALCISTA | 5.96% |  | HyperLemon Tech: Sindicato de IA publica manifiesto anti-limon | HLEM, HYP1, NEOL |
| 3 | 3 | BAJISTA | -4.68% |  | TurboBurger Labs: Semana de descuentos extremos en comida dudosa | TURB, HLEM, HYP1 |
| 3 | 4 | BAJISTA | -6.76% |  | Crisis de montacargas golpea a HyperPigeon Industries | HYPE, NEOL, PROT |
| 3 | 5 | BAJISTA | -15.25% |  | HyperLemon Tech despide a su IA por comprar limones | HLEM, HYP1, PROT |
| 3 | 5 | ALCISTA | 7.69% |  | Nueva receta de TurboBurger Labs con polvo meteoritico | TURB, PROT, HYPE |
| 3 | 6 | ALCISTA | 15.35% |  | HyperCrate Holdings Agro abre mercado de huertos con drones vaqueros en sesion de alta expectativa | HYP1, NEOL, TURB |
| 3 | 7 | BAJISTA | -20.00% |  | Proto-Volt Group Harvest: Ex directivo filtra chat interno comprometedor | PROT, DRFM, MEGA |
| 3 | 8 | BAJISTA | -18.11% |  | Proto-Volt Group Harvest: Boicot comunitario por marketing demasiado agresivo en plena tension reputacional | PROT, HLEM, HYP1 |
| 3 | 8 | ALCISTA | 8.60% |  | Proto-Volt Group Harvest promete superconductores de queso | PROT, MEGA, HLEM |
| 3 | 9 | BAJISTA | -9.22% |  | HyperLemon Tech: Varias companias anuncian reverse split de emergencia | HLEM, DRFM, HYP1 |
| 3 | 9 | BAJISTA | -8.49% |  | HyperLemon Tech: Hilo viral denuncia promesas infladas | HLEM, HYP1, NEOL |
| 3 | 10 | ALCISTA | 20.00% |  | Proto-Volt Group Harvest: Heladera de leche inteligente reduce facturas en sesion de alta expectativa | PROT, NEOL, HYP1 |
| 3 | 10 | ALCISTA | 12.68% |  | Neo-Lemon Systems Finance: Bateria de queso supera prueba de 48 horas | NEOL, PROT, HYP1 |
| 3 | 11 | BAJISTA | -13.41% |  | HyperCrate Holdings Agro: Auditoria automatica detecta clausulas explosivas bajo lupa normativa | HYP1, NEOL, PROT |
| 3 | 11 | MIXTA | -0.11% | ambiguous_signal | Proto-Volt Group Harvest: Agencia sanitaria abre ensayo acelerado | PROT, DRFM |
| 3 | 12 | ALCISTA | 19.13% |  | HyperLemon Tech: Foro nocturno elige nueva accion favorita | HLEM, PROT, MEGA |
| 3 | 13 | ALCISTA | 8.60% |  | Proto-Volt Group Harvest promete superconductores de queso | PROT, MEGA, HLEM |
| 3 | 13 | BAJISTA | -8.49% |  | HyperCrate Holdings Agro: Hilo viral denuncia promesas infladas | HYP1, HLEM, NEOL |
| 3 | 14 | BAJISTA | -15.25% |  | HyperLemon Tech despide a su IA por comprar limones | HLEM, HYP1, PROT |
| 3 | 14 | BAJISTA | -13.00% |  | HyperCrate Holdings Agro: El regulador avisa sobre acciones meme inestables | HYP1, NEOL, DRFM |
| 3 | 15 | BAJISTA | -4.68% |  | TurboBurger Labs: Semana de descuentos extremos en comida dudosa | TURB, HLEM, HYP1 |
| 3 | 15 | BAJISTA | -15.69% |  | Proto-Volt Group Harvest: Prohibicion temporal de exportar chips cuanticos tras nueva circular | PROT, NEOL, MEGA |
| 3 | 16 | ALCISTA | 12.26% |  | Proto-Volt Group Harvest anuncia envios interdimensionales | PROT, HYPE, MEGA |
| 3 | 17 | ALCISTA | 7.69% |  | Nueva receta de TurboBurger Labs con polvo meteoritico | TURB, HYPE, PROT |
| 3 | 17 | BAJISTA | -12.89% |  | HyperPigeon Industries: Sindicatos de palomas convocan paro general | HYPE, PROT, NEOL |
| 3 | 18 | BAJISTA | -6.76% |  | Crisis de montacargas golpea a HyperPigeon Industries con riesgo reputacional creciente | HYPE, NEOL, PROT |
| 3 | 18 | BAJISTA | -4.68% |  | TurboBurger Labs: Semana de descuentos extremos en comida dudosa | TURB, HLEM, HYP1 |
| 3 | 19 | BAJISTA | -15.09% |  | TurboBurger Labs aclara que sus productos no son muebles | TURB, HYP1, PROT |
| 3 | 20 | ALCISTA | 8.60% |  | Proto-Volt Group Harvest promete superconductores de queso segun operadores | PROT, MEGA, HLEM |
| 3 | 20 | ALCISTA | 15.35% |  | HyperCrate Holdings Agro abre mercado de huertos con drones vaqueros | HYP1, NEOL, TURB |
| 3 | 21 | ALCISTA | 12.73% |  | HyperLemon Tech: Oleada de rumores de fusiones imposibles | HLEM, DRFM, PROT |
| 3 | 21 | ALCISTA | 12.26% |  | Proto-Volt Group Harvest anuncia envios interdimensionales en sesion de alta expectativa | PROT, HYPE, MEGA |
| 3 | 22 | BAJISTA | -13.00% |  | HyperCrate Holdings Agro: El regulador avisa sobre acciones meme inestables bajo lupa normativa | HYP1, NEOL, DRFM |
| 3 | 22 | ALCISTA | 19.13% |  | HyperLemon Tech: Foro nocturno elige nueva accion favorita | HLEM, PROT, MEGA |
| 3 | 23 | BAJISTA | -13.41% |  | HyperCrate Holdings Agro: Auditoria automatica detecta clausulas explosivas tras nueva circular | HYP1, PROT, NEOL |
| 3 | 23 | ALCISTA | 5.96% |  | HyperLemon Tech: Sindicato de IA publica manifiesto anti-limon | HLEM, HYP1, NEOL |
| 3 | 24 | SIN_IMPACTO | 0.00% | no_impact_link, ambiguous_signal | Neo-Lemon Systems Finance: Se pierde satelite con paquetes premium |  |
| 3 | 24 | ALCISTA | 12.73% |  | HyperLemon Tech: Oleada de rumores de fusiones imposibles y dispara foros | HLEM, DRFM, PROT |
| 3 | 25 | ALCISTA | 8.01% |  | DreamFuel Pharma vende vitaminas de energia emocional segun operadores | DRFM, PROT, NEOL |
| 3 | 25 | BAJISTA | -6.76% |  | Crisis de montacargas golpea a HyperPigeon Industries | HYPE, NEOL, PROT |
| 3 | 26 | ALCISTA | 10.52% |  | Neo-Lemon Systems Finance: Fondo familiar entra fuerte en consumo domestico | NEOL, HYP1, PROT |
| 3 | 26 | BAJISTA | -15.69% |  | Proto-Volt Group Harvest: Prohibicion temporal de exportar chips cuanticos | PROT, NEOL, MEGA |
| 3 | 27 | BAJISTA | -18.11% |  | Proto-Volt Group Harvest: Boicot comunitario por marketing demasiado agresivo | PROT, HYP1, HLEM |
| 3 | 27 | ALCISTA | 8.60% |  | Proto-Volt Group Harvest promete superconductores de queso | PROT, MEGA, HLEM |
| 3 | 28 | BAJISTA | -20.00% |  | Proto-Volt Group Harvest: Ex directivo filtra chat interno comprometedor | PROT, DRFM, MEGA |
| 3 | 28 | ALCISTA | 15.35% |  | HyperCrate Holdings Agro abre mercado de huertos con drones vaqueros en sesion de alta expectativa | HYP1, NEOL, TURB |
| 3 | 29 | BAJISTA | -9.22% |  | HyperLemon Tech: Varias companias anuncian reverse split de emergencia | HLEM, DRFM, HYP1 |
| 3 | 29 | ALCISTA | 19.13% |  | HyperLemon Tech: Foro nocturno elige nueva accion favorita | HLEM, PROT, MEGA |
| 3 | 30 | BAJISTA | -12.89% |  | HyperPigeon Industries: Sindicatos de palomas convocan paro general | HYPE, NEOL, PROT |
| 3 | 30 | ALCISTA | 20.00% |  | Neo-Lemon Systems Finance: Subsidio estatal para energia domestica en sesion de alta expectativa | NEOL, HYP1, PROT |
| 4 | 1 | BAJISTA | -11.77% |  | HyperLemon Tech despide a su IA por comprar limones | HLEM, ULTR, GRMB |
| 4 | 1 | ALCISTA | 20.00% |  | SperCond: Bateria de queso supera prueba de 48 horas en sesion de alta expectativa | SPCD, ULTR, PIGE |
| 4 | 2 | ALCISTA | 13.04% |  | Nueva receta de UltraSoup Foods con polvo meteoritico y dispara foros | ULTR, ORSP, GRMB |
| 4 | 3 | BAJISTA | -19.61% |  | GrimBurger: Auditoria automatica detecta clausulas explosivas bajo lupa normativa | GRMB, PIGE, ULTR |
| 4 | 3 | ALCISTA | 12.63% |  | Pigeon Union: Heladera de leche inteligente reduce facturas | PIGE, GRMB, SPCD |
| 4 | 4 | BAJISTA | -15.78% |  | UltraSoup Foods: Prohibicion temporal de exportar chips cuanticos | ULTR, ORSP, SPCD |
| 4 | 4 | ALCISTA | 20.00% |  | KingMoo enfria servidores con una vaca estrategica en giro improbable | KMOO |
| 4 | 5 | ALCISTA | 20.00% |  | SperCond: Bateria de queso supera prueba de 48 horas | SPCD, ULTR, PIGE |
| 4 | 6 | BAJISTA | -18.98% |  | HyperLemon Tech: El regulador avisa sobre acciones meme inestables | HLEM, ULTR, GRMB |
| 4 | 7 | ALCISTA | 19.60% |  | UltraSoup Foods abre mercado de huertos con drones vaqueros segun operadores | ULTR, PIG1, KMOO |
| 4 | 8 | BAJISTA | -8.83% |  | GrimBurger: Agencia sanitaria abre ensayo acelerado | GRMB, PIGE, ORSP |
| 4 | 9 | ALCISTA | 16.78% |  | UltraSoup Foods: Patente para granjas cuanticas de microchips lacteos | ULTR, PIG1 |
| 4 | 9 | ALCISTA | 19.08% |  | HyperLemon Tech: Sindicato de IA publica manifiesto anti-limon | HLEM, ULTR, GRMB |
| 4 | 10 | BAJISTA | -11.77% |  | HyperLemon Tech despide a su IA por comprar limones | HLEM, ULTR, GRMB |
| 4 | 10 | BAJISTA | -15.78% |  | UltraSoup Foods: Prohibicion temporal de exportar chips cuanticos | ULTR, ORSP, SPCD |
| 4 | 11 | BAJISTA | -17.92% |  | HyperLemon Tech: Hilo viral denuncia promesas infladas | HLEM, ORSP, ULTR |
| 4 | 11 | BAJISTA | -14.38% |  | GrimBurger: Agencia sanitaria abre ensayo acelerado | GRMB, PIGE, ULTR |
| 4 | 12 | BAJISTA | -12.38% |  | HyperLemon Tech: Varias companias anuncian reverse split de emergencia | HLEM, ORSP, ULTR |
| 4 | 13 | BAJISTA | -18.36% |  | GrimBurger: Ex directivo filtra chat interno comprometedor | GRMB, PIGE, ULTR |
| 4 | 14 | ALCISTA | 7.48% |  | SperCond vende vitaminas de energia emocional segun operadores | SPCD, PIGE, HLEM |
| 4 | 14 | BAJISTA | -10.29% |  | GrimBurger aclara que sus productos no son muebles bajo lupa normativa | GRMB, PIGE, ORSP |
| 4 | 15 | ALCISTA | 9.22% |  | HyperLemon Tech: Oleada de rumores de fusiones imposibles | HLEM, GRMB, ULTR |
| 4 | 15 | ALCISTA | 9.43% |  | Orbital Soup firma contrato para comedores en estacion orbital | ORSP, ULTR, GRMB |
| 4 | 16 | ALCISTA | 19.60% |  | UltraSoup Foods abre mercado de huertos con drones vaqueros en sesion de alta expectativa | ULTR, PIG1, KMOO |
| 4 | 16 | BAJISTA | -11.77% |  | HyperLemon Tech despide a su IA por comprar limones | HLEM, ULTR, GRMB |
| 4 | 17 | ALCISTA | 14.61% |  | HyperLemon Tech: Oleada de rumores de fusiones imposibles y dispara foros | HLEM, ULTR, ORSP |
| 4 | 17 | ALCISTA | 18.47% |  | Orbital Soup: Nueva startup de comida espacial sale a bolsa con rally social inesperado | ORSP, HLEM, GRMB |
| 4 | 18 | BAJISTA | -20.00% |  | Pigeon Express: Tormenta geomagnetica bloquea rutas de transporte | PGEX, ORSP, PIG1 |
| 4 | 18 | BAJISTA | -11.54% |  | Crisis de montacargas golpea a Orbital Soup | ORSP, PGEX, GRMB |
| 4 | 19 | BAJISTA | -17.70% |  | GrimBurger aclara que sus productos no son muebles | GRMB, PIGE, ULTR |
| 4 | 20 | ALCISTA | 15.55% |  | SperCond promete superconductores de queso | SPCD, ULTR, GRMB |
| 4 | 20 | BAJISTA | -15.78% |  | UltraSoup Foods: Prohibicion temporal de exportar chips cuanticos tras nueva circular | ULTR, ORSP, SPCD |
| 4 | 20 | ALCISTA | 12.63% |  | Pigeon Union: Heladera de leche inteligente reduce facturas en sesion de alta expectativa | PIGE, SPCD, GRMB |
| 4 | 21 | ALCISTA | 11.77% |  | Pigeon Union: Fondo familiar entra fuerte en consumo domestico en sesion de alta expectativa | PIGE, GRMB, HLEM |
| 4 | 21 | BAJISTA | -20.00% |  | Pigeon Express: Tormenta geomagnetica bloquea rutas de transporte | PGEX, ORSP, PIG1 |
| 4 | 22 | ALCISTA | 19.08% |  | HyperLemon Tech: Sindicato de IA publica manifiesto anti-limon | HLEM, ULTR, GRMB |
| 4 | 22 | ALCISTA | 19.75% |  | UltraSoup Foods: Patente para granjas cuanticas de microchips lacteos | ULTR, SPCD |
| 4 | 23 | BAJISTA | -8.89% |  | Crisis de montacargas golpea a Orbital Soup | ORSP, PGEX, HLEM |
| 4 | 23 | ALCISTA | 20.00% |  | KingMoo enfria servidores con una vaca estrategica en giro improbable | KMOO |
| 4 | 24 | ALCISTA | 13.04% |  | Nueva receta de UltraSoup Foods con polvo meteoritico | ULTR, GRMB, ORSP |
| 4 | 25 | ALCISTA | 19.39% |  | Orbital Soup pone una lata en orbita baja | ORSP, HLEM, ULTR |
| 4 | 25 | BAJISTA | -18.98% |  | UltraSoup Foods: El regulador avisa sobre acciones meme inestables tras nueva circular | ULTR, GRMB, HLEM |
| 4 | 26 | ALCISTA | 10.64% |  | GrimBurger: Semana de descuentos extremos en comida dudosa | GRMB, PIGE, ORSP |
| 4 | 26 | ALCISTA | 12.63% |  | Pigeon Union: Heladera de leche inteligente reduce facturas en sesion de alta expectativa | PIGE, GRMB, SPCD |
| 4 | 27 | ALCISTA | 20.00% |  | HyperLemon Tech: Foro nocturno elige nueva accion favorita y dispara foros | HLEM, ULTR, ORSP |
| 4 | 27 | BAJISTA | -18.98% |  | UltraSoup Foods: El regulador avisa sobre acciones meme inestables tras nueva circular | ULTR, HLEM, GRMB |
| 4 | 28 | ALCISTA | 19.60% |  | UltraSoup Foods abre mercado de huertos con drones vaqueros | ULTR, PIG1, KMOO |
| 4 | 28 | ALCISTA | 14.61% |  | HyperLemon Tech: Oleada de rumores de fusiones imposibles con rally social inesperado | HLEM, ORSP, GRMB |
| 4 | 29 | ALCISTA | 9.43% |  | Orbital Soup firma contrato para comedores en estacion orbital en sesion de alta expectativa | ORSP, ULTR, GRMB |
| 4 | 30 | ALCISTA | 9.49% |  | Pigeon Express anuncia envios interdimensionales | PGEX, ORSP, HLEM |
| 4 | 30 | BAJISTA | -10.29% |  | GrimBurger aclara que sus productos no son muebles tras nueva circular | GRMB, PIGE, ORSP |
| 5 | 1 | BAJISTA | -0.76% | ambiguous_signal | Tostadoras de BabyVolt exigen vacaciones | BBVT, QUAN, DRFM |
| 5 | 1 | BAJISTA | -9.57% |  | Quantum Lemon Holdings: Sindicatos de palomas convocan paro general en plena tension reputacional | QUAN, KING, ORSP |
| 5 | 2 | BAJISTA | -11.67% |  | HyperLemon Tech despide a su IA por comprar limones | HLEM, NANO, BBVT |
| 5 | 2 | ALCISTA | 7.69% |  | Quantum Lemon Holdings anuncia envios interdimensionales | QUAN, ORSP, DRFM |
| 5 | 3 | ALCISTA | 3.27% |  | Orbital Soup: Semana de descuentos extremos en comida dudosa | ORSP, HLEM, KING |
| 5 | 3 | ALCISTA | 12.52% |  | Orbital Soup firma contrato para comedores en estacion orbital | ORSP, DRFM, NANO |
| 5 | 4 | BAJISTA | -3.52% |  | KingSoup Express: Sindicatos de palomas convocan paro general con riesgo reputacional creciente | KING, QUAN, HLEM |
| 5 | 4 | BAJISTA | -16.07% |  | Orbital Soup: Boicot comunitario por marketing demasiado agresivo | ORSP, HLEM, QUAN |
| 5 | 5 | ALCISTA | 12.52% |  | Orbital Soup firma contrato para comedores en estacion orbital en sesion de alta expectativa | ORSP, DRFM, NANO |
| 5 | 5 | ALCISTA | 14.20% |  | DreamFuel Pharma vende vitaminas de energia emocional en sesion de alta expectativa | DRFM, SPCD, QUAN |
| 5 | 6 | BAJISTA | -2.88% |  | Crisis de montacargas golpea a Orbital Soup | ORSP, HLEM, DRFM |
| 5 | 6 | ALCISTA | 9.20% |  | DreamFuel Pharma: Fondo familiar entra fuerte en consumo domestico | DRFM, QUAN, BBVT |
| 5 | 7 | BAJISTA | -16.17% |  | DreamFuel Pharma: Tormenta geomagnetica bloquea rutas de transporte | DRFM, ORSP, BBVT |
| 5 | 7 | BAJISTA | -12.45% |  | DreamFuel Pharma: Ex directivo filtra chat interno comprometedor | DRFM, ORSP, HLEM |
| 5 | 8 | ALCISTA | 18.58% |  | Orbital Soup pone una lata en orbita baja | ORSP, DRFM, HLEM |
| 5 | 8 | ALCISTA | 13.84% |  | Nueva receta de DreamFuel Pharma con polvo meteoritico y dispara foros | ORSP, DRFM, KING |
| 5 | 9 | ALCISTA | 18.58% |  | Orbital Soup: Nueva startup de comida espacial sale a bolsa | ORSP, DRFM, HLEM |
| 5 | 9 | BAJISTA | -12.64% |  | DreamFuel Pharma: Auditoria automatica detecta clausulas explosivas | DRFM, HLEM, KING |
| 5 | 10 | ALCISTA | 14.20% |  | DreamFuel Pharma vende vitaminas de energia emocional | DRFM, SPCD, QUAN |
| 5 | 10 | BAJISTA | -16.70% |  | SperCond: Prohibicion temporal de exportar chips cuanticos bajo lupa normativa | SPCD, QUAN |
| 5 | 11 | BAJISTA | -11.67% |  | HyperLemon Tech despide a su IA por comprar limones con riesgo reputacional creciente | HLEM, NANO, BBVT |
| 5 | 11 | BAJISTA | -12.45% |  | DreamFuel Pharma: Ex directivo filtra chat interno comprometedor | DRFM, ORSP, HLEM |
| 5 | 12 | ALCISTA | 19.02% |  | HyperLemon Tech abre mercado de huertos con drones vaqueros | HLEM, NANO, SPCD |
| 5 | 12 | ALCISTA | 12.52% |  | Orbital Soup firma contrato para comedores en estacion orbital segun operadores | ORSP, DRFM, NANO |
| 5 | 13 | ALCISTA | 17.25% |  | HyperLemon Tech: Oleada de rumores de fusiones imposibles | HLEM, DRFM, ORSP |
| 5 | 13 | BAJISTA | -15.65% |  | HyperLemon Tech: Hilo viral denuncia promesas infladas | HLEM, DRFM, ORSP |
| 5 | 14 | BAJISTA | -9.53% |  | HyperLemon Tech: Varias companias anuncian reverse split de emergencia | HLEM, DRFM, KING |
| 5 | 15 | ALCISTA | 7.69% |  | Quantum Lemon Holdings anuncia envios interdimensionales segun operadores | QUAN, ORSP, DRFM |
| 5 | 15 | BAJISTA | -16.17% |  | DreamFuel Pharma: Tormenta geomagnetica bloquea rutas de transporte | DRFM, ORSP, BBVT |
| 5 | 16 | BAJISTA | -3.52% |  | Quantum Lemon Holdings: Sindicatos de palomas convocan paro general | QUAN, KING, HLEM |

