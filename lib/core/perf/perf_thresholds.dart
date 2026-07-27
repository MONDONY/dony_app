// Seuils de performance pour le harness perf yadony.
// Ces constantes définissent les limites PASS / WARN / FAIL
// utilisées par tool/parse_timeline.dart et les tests associés.

/// Temps moyen de build par frame (ms) — en-dessous = bon
const double kAvgBuildGood = 8.0;

/// Temps moyen de build par frame (ms) — au-delà = FAIL
const double kAvgBuildWarn = 12.0;

/// Pire frame build (ms) — en-dessous = bon
const double kWorstBuildGood = 16.67;

/// Pire frame build (ms) — au-delà = FAIL
const double kWorstBuildWarn = 33.0;

/// Pourcentage de frames janky (build) — en-dessous = bon
const double kJankPctGood = 0.01;

/// Pourcentage de frames janky (build) — au-delà = FAIL
const double kJankPctWarn = 0.05;

/// Temps moyen de rasterisation par frame (ms) — en-dessous = bon
const double kAvgRasterGood = 8.0;

/// Temps moyen de rasterisation par frame (ms) — au-delà = FAIL
const double kAvgRasterWarn = 12.0;

/// Pire frame raster (ms) — en-dessous = bon
const double kWorstRasterGood = 16.67;

/// Pire frame raster (ms) — au-delà = FAIL
const double kWorstRasterWarn = 33.0;

/// Pourcentage de frames janky (raster) — en-dessous = bon
const double kJankRasterGood = 0.01;

/// Pourcentage de frames janky (raster) — au-delà = FAIL
const double kJankRasterWarn = 0.05;
