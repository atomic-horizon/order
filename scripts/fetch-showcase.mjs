// Fetches names, icons and stats for the homepage showcase from Roblox's web
// APIs and writes pages/showcase.json. Runs at build time, since Roblox's APIs
// don't allow requests from the browser. On any failure it keeps the existing
// data and exits 0, so a Roblox outage never blocks a docs deploy.
//
// Usage: node scripts/fetch-showcase.mjs

import { mkdir, writeFile } from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

const SHOWCASE_PLACE_IDS = [15694891095, 95047916580305]

const REPOSITORY_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const SHOWCASE_DATA_PATH = path.join(REPOSITORY_ROOT, "pages", "showcase.json")
const ICON_DIRECTORY = path.join(REPOSITORY_ROOT, ".moonwave", "static", "img", "showcase")
const REQUEST_TIMEOUT_MILLISECONDS = 15000

async function fetchJson(url) {
	const response = await fetch(url, {
		headers: { Accept: "application/json" },
		signal: AbortSignal.timeout(REQUEST_TIMEOUT_MILLISECONDS),
	})
	if (!response.ok) {
		throw new Error(`${url} responded with ${response.status}`)
	}
	return response.json()
}

async function fetchUniverseId(placeId) {
	const universeResponse = await fetchJson(`https://apis.roblox.com/universes/v1/places/${placeId}/universe`)
	if (typeof universeResponse.universeId !== "number") {
		throw new Error(`No universe found for place ${placeId}`)
	}
	return universeResponse.universeId
}

async function downloadIcon(imageUrl, universeId) {
	const response = await fetch(imageUrl, { signal: AbortSignal.timeout(REQUEST_TIMEOUT_MILLISECONDS) })
	if (!response.ok) {
		throw new Error(`Icon download for universe ${universeId} responded with ${response.status}`)
	}
	const iconBytes = Buffer.from(await response.arrayBuffer())
	await writeFile(path.join(ICON_DIRECTORY, `${universeId}.png`), iconBytes)
}

async function buildShowcase() {
	const universeIds = await Promise.all(SHOWCASE_PLACE_IDS.map(fetchUniverseId))
	const universeIdList = universeIds.join(",")

	const [gamesResponse, iconsResponse] = await Promise.all([
		fetchJson(`https://games.roblox.com/v1/games?universeIds=${universeIdList}`),
		fetchJson(
			`https://thumbnails.roblox.com/v1/games/icons?universeIds=${universeIdList}&size=512x512&format=Png&isCircular=false`
		),
	])

	const gamesByUniverseId = new Map(gamesResponse.data.map((gameDetails) => [gameDetails.id, gameDetails]))
	const iconUrlsByUniverseId = new Map(
		iconsResponse.data
			.filter((iconDetails) => iconDetails.state === "Completed" && iconDetails.imageUrl)
			.map((iconDetails) => [iconDetails.targetId, iconDetails.imageUrl])
	)

	await mkdir(ICON_DIRECTORY, { recursive: true })

	const games = []
	for (const [index, placeId] of SHOWCASE_PLACE_IDS.entries()) {
		const universeId = universeIds[index]
		const gameDetails = gamesByUniverseId.get(universeId)
		const iconUrl = iconUrlsByUniverseId.get(universeId)
		if (!gameDetails || !iconUrl) {
			throw new Error(`Missing details or icon for universe ${universeId}`)
		}

		await downloadIcon(iconUrl, universeId)

		games.push({
			placeId,
			universeId,
			name: gameDetails.name,
			url: `https://www.roblox.com/games/${placeId}`,
			icon: `/img/showcase/${universeId}.png`,
			visits: gameDetails.visits,
			favorites: gameDetails.favoritedCount,
		})
	}

	return { fetchedAt: new Date().toISOString(), games }
}

try {
	const showcase = await buildShowcase()
	await writeFile(SHOWCASE_DATA_PATH, `${JSON.stringify(showcase, null, "\t")}\n`)
	for (const gameEntry of showcase.games) {
		console.log(`${gameEntry.name}: ${gameEntry.visits} visits, ${gameEntry.favorites} favorites`)
	}
} catch (fetchError) {
	console.warn(`::warning::Could not refresh showcase data, keeping the existing file: ${fetchError.message}`)
}
