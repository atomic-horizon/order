import Head from "@docusaurus/Head"
import Link from "@docusaurus/Link"
import useBaseUrl from "@docusaurus/useBaseUrl"
import CodeBlock from "@theme/CodeBlock"
import Layout from "@theme/Layout"
import clsx from "clsx"
import React from "react"
import styles from "./index.module.css"
import showcase from "./showcase.json"

// ── Hero sample ──────────────────────────────────────────────────────────────

const HERO_CODE = `local GetRemote = shared("GetRemote")
local PlayerData = shared("PlayerData")

local CombatService = {}

function CombatService:Init()
    GetRemote("Attack"):OnEvent(function(player)
        PlayerData:IncrementNumValue(player, "Hits", 1)
    end)
end

return CombatService`

// ── Pillars ──────────────────────────────────────────────────────────────────

const PILLARS = [
	{
		title: "Load anything by name",
		points: [
			<>
				Replace <code>require()</code> paths with <code>shared("ModuleName")</code>, or a partial path when two
				modules share a name.
			</>,
			"Modules can depend on each other in a cycle. Order resolves them for you.",
			"Use modules from other frameworks by pointing their require at shared.",
		],
		link: "/docs/usage#loading-dependencies",
	},
	{
		title: "Predictable startup",
		points: [
			<>
				Every task runs a synchronous <code>Prep</code>, then an async <code>Init</code>, on the client and the
				server.
			</>,
			<>
				Set a <code>Priority</code> to load a task earlier or later, and choose how init phases run across tasks.
			</>,
			"Code groups load only the code each place needs, so a lobby and a game server can share one project.",
		],
		link: "/docs/usage#tasks",
	},
	{
		title: "Batteries included",
		points: [
			<>
				<Link to="/docs/player-data">Player data</Link> saved with ProfileStore and replicated to each client.
			</>,
			<>
				<Link to="/docs/networking">Networking</Link> through <code>GetRemote</code>, and UI panes and buttons
				with <Link to="/docs/atomicui">AtomicUI</Link>.
			</>,
			<>
				<Link to="/docs/developer-tools">Developer tools</Link>: a Cmdr console, a place switcher, and
				permissions.
			</>,
		],
		link: "/docs/player-data",
	},
]

// ── How it works ─────────────────────────────────────────────────────────────

const CODE_SNIPPETS = [
	{
		label: "1. Write a task",
		description: "Any module in a tasks folder is a task. Order finds it and runs it, so there is no list to keep up to date.",
		code: `local PlayerService = {
    -- Higher values load first
    Priority = 10,
}

-- Synchronous setup phase
function PlayerService:Prep()
    self.Cache = {}
end

-- Async runtime phase
function PlayerService:Init()
    local DataManager = shared("DataManager")
    DataManager:LoadAll(self.Cache)
end

return PlayerService`,
	},
	{
		label: "2. Load modules by name",
		description: "Ask for a module by name from anywhere. Use a partial path or the ModuleScript itself when you need to be specific.",
		code: `-- Load a module by name (no path required)
local DataManager = shared("DataManager")

-- Or by partial path for disambiguation
local GetRemote = shared("lib/GetRemote")

-- Or by direct ModuleScript reference
local Util = shared(game.ReplicatedStorage.Shared.Util)`,
	},
	{
		label: "3. Reference each other",
		description: "Modules can load each other in a cycle. Order runs every Prep, then every Init, in priority order.",
		code: `-- ModuleA.luau
local ModuleA = {}

function ModuleA:DoThing()
    -- Safe! ModuleB is resolved lazily
    local ModuleB = shared("ModuleB")
    return ModuleB:GetValue()
end

return ModuleA

-- ModuleB.luau
local ModuleB = {}

function ModuleB:GetValue()
    local ModuleA = shared("ModuleA")
    return ModuleA ~= nil
end

return ModuleB`,
	},
]

// ── Showcase ──────────────────────────────────────────────────────────────────

// Stats come from showcase.json, which scripts/fetch-showcase.mjs refreshes at
// build time
const COMPACT_NUMBER_FORMAT = new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 1 })
const STATS_DATE_FORMAT = new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric", timeZone: "UTC" })

function ShowcaseGame({ name, url, icon, visits, favorites }) {
	const iconUrl = useBaseUrl(icon)

	return (
		<a className={styles.showcaseCard} href={url} target="_blank" rel="noopener noreferrer">
			<img className={styles.showcaseIcon} src={iconUrl} alt={`${name} icon`} width="96" height="96" loading="lazy" />
			<div className={styles.showcaseBody}>
				<h3 className={styles.showcaseName}>
					{name} <span aria-hidden="true">↗</span>
				</h3>
				<dl className={styles.showcaseStats}>
					<div>
						<dt>Visits</dt>
						<dd>{COMPACT_NUMBER_FORMAT.format(visits)}</dd>
					</div>
					<div>
						<dt>Favorites</dt>
						<dd>{COMPACT_NUMBER_FORMAT.format(favorites)}</dd>
					</div>
				</dl>
			</div>
		</a>
	)
}

function Showcase() {
	return (
		<section id="used-in-production" className={styles.showcase}>
			<div className="container">
				<h2 className={styles.sectionHeading}>Used in Production</h2>
				<p className={styles.sectionSubheading}>Order powers live Roblox experiences played by millions.</p>
				<div className={styles.showcaseHighlight}>
					<span className={styles.showcaseHighlightNumber}>800,000+</span>
					<span className={styles.showcaseHighlightText}>
						<strong>Battle-tested at scale:</strong> sustained over 800,000 concurrent users with no errors
						during the Roblox Innovation Awards 2026 event in The Block.
					</span>
				</div>
				<div className={styles.showcaseGrid}>
					{showcase.games.map((gameEntry) => (
						<ShowcaseGame key={gameEntry.universeId} {...gameEntry} />
					))}
				</div>
				<p className={styles.showcaseUpdated}>
					Stats updated {STATS_DATE_FORMAT.format(new Date(showcase.fetchedAt))}
				</p>
				<p className={styles.showcaseContact}>
					Want to showcase your Order project here too? Contact <strong>@chiefwildin</strong> on Discord.
				</p>
			</div>
		</section>
	)
}

// ── Components ────────────────────────────────────────────────────────────────

const PITCH =
	"A lightweight framework for structuring Roblox games: load any module by name, control how your game starts up, and use the systems most games need without building them first."

function HomepageHeader() {
	return (
		<header className={clsx("hero", styles.heroBanner)}>
			<div className={clsx("container", styles.heroLayout)}>
				<div className={styles.heroText}>
					<h1 className="hero__title">Order</h1>
					<p className={styles.heroPitch}>{PITCH}</p>
					<p className={styles.heroDescription}>
						Less wiring between modules, and the same startup order on the client and the server every time.
					</p>
					<div className={styles.buttons}>
						<Link className="button button--primary button--lg" to="/docs/intro">
							Get Started
						</Link>
						<a
							className={clsx("button button--secondary button--lg", styles.heroSecondaryButton)}
							href="https://github.com/atomic-horizon/order"
							target="_blank"
							rel="noopener noreferrer"
						>
							View on GitHub
						</a>
					</div>
					<div className={styles.heroMeta}>
						<span className={styles.heroBadge}>v3.1.0</span>
						<span className={styles.heroBadge}>Roblox</span>
						<span className={styles.heroBadge}>Luau</span>
					</div>
				</div>
				<div className={styles.heroCode}>
					<CodeBlock language="lua">{HERO_CODE}</CodeBlock>
				</div>
			</div>
		</header>
	)
}

function ProofStrip() {
	return (
		<a className={styles.proofStrip} href="#used-in-production">
			<div className={clsx("container", styles.proofStripInner)}>
				<span className={styles.proofIcons}>
					{showcase.games.map((gameEntry) => (
						<ProofIcon key={gameEntry.universeId} {...gameEntry} />
					))}
				</span>
				<span>
					Powers <strong>{showcase.games.map((gameEntry) => gameEntry.name).join(" and ")}</strong>
				</span>
				<span className={styles.proofDivider} aria-hidden="true" />
				<span>
					<strong>800,000+</strong> concurrent users, no errors
				</span>
				<span className={styles.proofArrow} aria-hidden="true">
					↓
				</span>
			</div>
		</a>
	)
}

function ProofIcon({ name, icon }) {
	return <img className={styles.proofIcon} src={useBaseUrl(icon)} alt={name} width="32" height="32" />
}

function Pillars() {
	return (
		<section className={styles.features}>
			<div className="container">
				<h2 className={styles.sectionHeading}>Why Order?</h2>
				<p className={styles.sectionSubheading}>
					Spend your time on gameplay instead of plumbing between modules.
				</p>
				<div className={styles.pillarGrid}>
					{PILLARS.map((pillar) => (
						<div key={pillar.title} className={styles.featureCard}>
							<h3 className={styles.pillarTitle}>{pillar.title}</h3>
							<ul className={styles.pillarPoints}>
								{pillar.points.map((point, index) => (
									<li key={index}>{point}</li>
								))}
							</ul>
							<Link className={styles.pillarLink} to={pillar.link}>
								Learn more →
							</Link>
						</div>
					))}
				</div>
			</div>
		</section>
	)
}

function HowItWorks() {
	const [activeIndex, setActiveIndex] = React.useState(0)
	const activeSnippet = CODE_SNIPPETS[activeIndex]

	return (
		<section className={styles.codeShowcase}>
			<div className="container">
				<h2 className={styles.sectionHeading}>How it works</h2>
				<p className={styles.sectionSubheading}>
					Write a task, reference other modules by name, and Order initializes everything in order.
				</p>
				<div className={styles.codePanel}>
					<div className={styles.codeTabs} role="tablist">
						{CODE_SNIPPETS.map((snippet, index) => (
							<button
								key={snippet.label}
								role="tab"
								aria-selected={activeIndex === index}
								className={clsx(styles.codeTab, { [styles.codeTabActive]: activeIndex === index })}
								onClick={() => setActiveIndex(index)}
							>
								{snippet.label}
							</button>
						))}
					</div>
					<p className={styles.codeDescription}>{activeSnippet.description}</p>
					<div className={styles.codeBlockWrapper}>
						<CodeBlock language="lua">{activeSnippet.code}</CodeBlock>
					</div>
				</div>
			</div>
		</section>
	)
}

// A template string keeps the line breaks, which JSX text would collapse
const SETUP_COMMANDS = `rokit install
forest install
rojo serve default.project.json`

function ClosingCallToAction() {
	return (
		<section className={styles.closing}>
			<div className="container">
				<h2 className={styles.closingHeading}>Get started in minutes</h2>
				<p className={styles.closingText}>
					Create a project from the template, install its packages, and sync it into Studio with Rojo.
				</p>
				<div className={styles.closingCommand}>
					<CodeBlock language="bash">{SETUP_COMMANDS}</CodeBlock>
				</div>
				<p className={styles.closingNote}>
					Prefer Wally? <code>wally install</code> works too.
				</p>
				<Link className={clsx("button button--lg", styles.closingButton)} to="/docs/intro">
					Get Started
				</Link>
			</div>
		</section>
	)
}

const TITLE = "Order"

export default function Home() {
	return (
		<>
			<Layout title={TITLE} description={PITCH}>
				<HomepageHeader />
				<ProofStrip />
				<main>
					<Pillars />
					<HowItWorks />
					<Showcase />
					<ClosingCallToAction />
				</main>
			</Layout>
			<Head>
				<title>{TITLE}</title>
				<meta property="og:type" content="website" />
				<meta property="og:title" content={TITLE} />
				<meta property="og:description" content={PITCH} />
				<meta property="og:image" content="https://atomic-horizon.github.io/order/img/embed_banner.png" />
				<meta property="twitter:domain" content="atomic-horizon.github.io" />
				<meta property="twitter:url" content="https://atomic-horizon.github.io/order/" />
				<meta name="twitter:image" content="https://atomic-horizon.github.io/order/img/embed_banner.png" />
			</Head>
		</>
	)
}
