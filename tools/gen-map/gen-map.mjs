// NET War — gera o mapa-múndi em matriz de pontos a partir do Natural Earth (world-atlas, domínio público).
//
//   node gen-map.mjs            → out/netwar_map.png (2400×992, pontos brancos, fundo transparente, passo 1,25°)
//                                 + r6/scripts/NetWar/UI/MapDots.reds (grade grossa para a tela sem textura)
//   node gen-map.mjs --step 5   → muda o passo da grade grossa (padrão 5°)
//
// Projeção do plano: lon −135..160, lat 72..−50, área 1200×496 (o PNG é 2×).
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { geoContains } from "d3-geo";
import { feature } from "topojson-client";
import { PNG } from "pngjs";

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, "..", "..");
const args = process.argv.slice(2);
const coarseStep = Number(args[args.indexOf("--step") + 1]) || 5;

const LON0 = -135, LON1 = 160, LAT0 = 72, LAT1 = -50;
const W = 1200, H = 496;
const toX = (lon) => (lon + 135) * (W / 295);
const toY = (lat) => (72 - lat) * (H / 122);

const topo = JSON.parse(readFileSync(join(here, "node_modules/world-atlas/land-50m.json"), "utf8"));
const land = feature(topo, topo.objects.land);
const isLand = (lon, lat) => geoContains(land, [lon, lat]);

function grid(step) {
  const pts = [];
  // Centraliza os pontos na célula para não grudar nas bordas.
  for (let lat = LAT0 - step / 2; lat > LAT1; lat -= step) {
    for (let lon = LON0 + step / 2; lon < LON1; lon += step) {
      if (isLand(lon, lat)) pts.push([lon, lat]);
    }
  }
  return pts;
}

// 1) Textura final (fase 4b, via WolvenKit + ArchiveXL).
const fine = grid(1.25);
const png = new PNG({ width: W * 2, height: H * 2 });
const r = 2; // raio do ponto em px na textura 2×
for (const [lon, lat] of fine) {
  const cx = Math.round(toX(lon) * 2), cy = Math.round(toY(lat) * 2);
  for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
    if (dx * dx + dy * dy > r * r) continue;
    const x = cx + dx, y = cy + dy;
    if (x < 0 || y < 0 || x >= png.width || y >= png.height) continue;
    const i = (png.width * y + x) << 2;
    png.data[i] = png.data[i + 1] = png.data[i + 2] = 255;
    png.data[i + 3] = 255;
  }
}
mkdirSync(join(here, "out"), { recursive: true });
writeFileSync(join(here, "out", "netwar_map.png"), PNG.sync.write(png));

// 2) Grade grossa para a tela em ink sem textura (cada ponto vira um widget: manter poucos).
const coarse = grid(coarseStep);
const flat = coarse.flatMap(([lon, lat]) => [Math.round(toX(lon)), Math.round(toY(lat))]);
const lines = [];
for (let i = 0; i < flat.length; i += 24) lines.push("      " + flat.slice(i, i + 24).join(", "));
const reds = `// Gerado por tools/gen-map/gen-map.mjs (passo ${coarseStep}°, ${coarse.length} pontos). Não editar à mão.
// Pares x, y na área do mapa de 1200×496. Some quando a textura do mapa entrar via ArchiveXL.
module NetWar.UI

public abstract class NWMapDots {
  public static func Step() -> Int32 { return ${coarseStep}; }
  public static func Points() -> array<Int32> {
    return [
${lines.join(",\n")}
    ];
  }
}
`;
writeFileSync(join(repo, "r6", "scripts", "NetWar", "UI", "MapDots.reds"), reds);
console.log(`textura: ${fine.length} pontos → out/netwar_map.png`);
console.log(`grade grossa: ${coarse.length} pontos (passo ${coarseStep}°) → r6/scripts/NetWar/UI/MapDots.reds`);
