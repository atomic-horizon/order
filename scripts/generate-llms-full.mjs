// Concatenates every docs page into .moonwave/static/llms-full.txt, a plain
// text copy of the docs for AI answer engines (see llmstxt.org). Front matter
// and MDX-only syntax are removed so the file reads as ordinary Markdown.
//
// Usage: node scripts/generate-llms-full.mjs

import { readdir, readFile, writeFile } from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

const SITE_URL = "https://order.atomichorizon.net"
const REPOSITORY_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const DOCS_DIRECTORY = path.join(REPOSITORY_ROOT, "docs")
const OUTPUT_PATH = path.join(REPOSITORY_ROOT, ".moonwave", "static", "llms-full.txt")

function parseFrontMatter(fileText) {
	const frontMatterMatch = fileText.match(/^---\n([\s\S]*?)\n---\n/)
	if (!frontMatterMatch) {
		return { fields: {}, body: fileText }
	}

	const fields = {}
	for (const line of frontMatterMatch[1].split("\n")) {
		const fieldMatch = line.match(/^(\w+):\s*(.*)$/)
		if (fieldMatch) {
			fields[fieldMatch[1]] = fieldMatch[2].replace(/^"(.*)"$/, "$1").replace(/\\"/g, '"')
		}
	}

	return { fields, body: fileText.slice(frontMatterMatch[0].length) }
}

// Turns MDX into plain Markdown: drops imports, keeps each tab's label as a
// heading, and strips the remaining JSX tags while keeping their contents
function toPlainMarkdown(markdownBody) {
	return markdownBody
		.replace(/^import\s.+$/gm, "")
		.replace(/<TabItem[^>]*label="([^"]+)"[^>]*>/g, "**$1:**")
		.replace(/<\/?(Tabs|TabItem|details|summary|Link)[^>]*>/g, "")
		.replace(/\]\(\/(?!\/)/g, `](${SITE_URL}/`)
		.replace(/\]\(([a-z][a-z-]*(?:#[\w-]+)?)\)/g, `](${SITE_URL}/docs/$1)`)
		.replace(/\n{3,}/g, "\n\n")
		.trim()
}

async function generateLlmsFull() {
	const docFileNames = (await readdir(DOCS_DIRECTORY)).filter((fileName) => /\.mdx?$/.test(fileName))

	const docs = await Promise.all(
		docFileNames.map(async (fileName) => {
			const { fields, body } = parseFrontMatter(await readFile(path.join(DOCS_DIRECTORY, fileName), "utf8"))
			const slug = fileName.replace(/\.mdx?$/, "")
			return {
				slug,
				title: fields.title ?? slug,
				description: fields.description,
				position: Number(fields.sidebar_position ?? Number.MAX_SAFE_INTEGER),
				body: toPlainMarkdown(body),
			}
		})
	)
	docs.sort((first, second) => first.position - second.position)

	const sections = docs.map((doc) =>
		[
			`<!-- ${SITE_URL}/docs/${doc.slug} -->`,
			doc.description ? `> ${doc.description}\n` : "",
			doc.body,
		]
			.filter(Boolean)
			.join("\n")
	)

	const header = [
		"# Order",
		"",
		"> Order is a free, open-source (MIT) Luau framework for Roblox games. It loads any module by name with `shared()`, starts every task in a predictable order on the client and the server, and includes player data, networking, UI and developer tools.",
		"",
		`This file contains every page of the Order docs (${SITE_URL}). The API reference is at ${SITE_URL}/api.`,
	].join("\n")

	await writeFile(OUTPUT_PATH, `${header}\n\n${sections.join("\n\n---\n\n")}\n`)
	console.log(`Wrote ${docs.length} docs pages to ${path.relative(REPOSITORY_ROOT, OUTPUT_PATH)}`)
}

await generateLlmsFull()
