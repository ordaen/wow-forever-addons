// Node loader hook: lets a design-site module load the way Vite serves it: JSON without `with { type: "json" }`,
// and `?raw` imports as the file's text.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export async function load(url, context, next) {
	if (url.endsWith("?raw")) {
		const text = readFileSync(fileURLToPath(url.slice(0, -4)), "utf8");
		return { format: "module", source: `export default ${JSON.stringify(text)};`, shortCircuit: true };
	}
	if (url.endsWith(".json")) {
		return next(url, { ...context, importAttributes: { type: "json" } });
	}
	return next(url, context);
}
