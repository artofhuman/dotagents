/**
 * Footer for pi. Feeds Claude Code statusline JSON to the shared
 * ~/.config/agents/statusline.sh and shows its output.
 */

import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const SCRIPT = join(homedir(), ".config/agents/statusline.sh");

type Limit = { percent: number; resetsAt?: number };

// 5h window from provider headers (Anthropic subscription, ChatGPT/Codex).
function parseLimit(h: Record<string, string | undefined>): Limit | undefined {
	const anth = h["anthropic-ratelimit-unified-5h-utilization"];
	if (anth != null) {
		const reset = Number(h["anthropic-ratelimit-unified-5h-reset"]);
		return { percent: Number(anth) * 100, resetsAt: reset > 0 ? reset : undefined };
	}
	const codex = h["x-codex-primary-used-percent"];
	if (codex != null) {
		const after = Number(h["x-codex-primary-reset-after-seconds"]);
		return {
			percent: Number(codex),
			resetsAt: Number.isFinite(after) ? Math.floor(Date.now() / 1000 + after) : undefined,
		};
	}
	return undefined;
}

function run(input: string, cwd: string): Promise<string> {
	return new Promise((resolve) => {
		const p = spawn(SCRIPT, [], { cwd, stdio: ["pipe", "pipe", "ignore"] });
		let out = "";
		const timer = setTimeout(() => p.kill(), 3000);
		p.stdout.on("data", (d) => (out += d));
		p.on("error", () => resolve(""));
		p.on("close", () => {
			clearTimeout(timer);
			resolve(out.trim());
		});
		p.stdin.on("error", () => {});
		p.stdin.end(input);
	});
}

export default function (pi: ExtensionAPI) {
	let line = "";
	let limit: Limit | undefined;
	let seq = 0;
	let requestRender: (() => void) | undefined;

	async function refresh(ctx: ExtensionContext) {
		const id = ++seq;
		const usage = ctx.getContextUsage();
		const level = ctx.thinkingLevel;
		const input = {
			model: { display_name: ctx.model ? ctx.model.name || ctx.model.id : "?" },
			effort: level && level !== "off" ? { level } : undefined,
			workspace: { project_dir: ctx.cwd },
			context_window: usage?.percent != null ? { used_percentage: usage.percent } : undefined,
			rate_limits: limit
				? { five_hour: { used_percentage: limit.percent, resets_at: limit.resetsAt } }
				: undefined,
		};
		const out = await run(JSON.stringify(input), ctx.cwd);
		if (id !== seq) return;
		line = out;
		requestRender?.();
	}

	pi.on("session_start", async (_event, ctx) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsub = footerData.onBranchChange(() => void refresh(ctx));
			return {
				dispose() {
					unsub();
					requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const statuses = [...footerData.getExtensionStatuses().values()].filter(Boolean);
					const text = [line, ...statuses].filter(Boolean).join(" | ");
					return [truncateToWidth(theme.fg("dim", text), width)];
				},
			};
		});
		await refresh(ctx);
	});

	pi.on("turn_end", async (_event, ctx) => refresh(ctx));
	pi.on("agent_end", async (_event, ctx) => refresh(ctx));
	pi.on("model_select", async (_event, ctx) => refresh(ctx));
	pi.on("thinking_level_select", async (_event, ctx) => refresh(ctx));

	pi.on("after_provider_response", (event) => {
		const next = parseLimit(event.headers as Record<string, string | undefined>);
		if (next) limit = next;
	});
}
