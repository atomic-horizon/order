import Head from "@docusaurus/Head"
import Link from "@docusaurus/Link"
import useDocusaurusContext from "@docusaurus/useDocusaurusContext"
import CodeBlock from "@theme/CodeBlock"
import Layout from "@theme/Layout"
import clsx from "clsx"
import React from "react"
import styles from "./index.module.css"

// ── Feature icons ────────────────────────────────────────────────────────────

function IconCycle() {
	return (
		<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
			<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
			<path d="M3 3v5h5" />
		</svg>
	)
}

function IconModule() {
	return (
		<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
			<rect x="2" y="3" width="6" height="6" rx="1" />
			<rect x="9" y="3" width="6" height="6" rx="1" />
			<rect x="16" y="3" width="6" height="6" rx="1" />
			<rect x="2" y="12" width="6" height="6" rx="1" />
			<rect x="9" y="12" width="6" height="6" rx="1" />
			<rect x="16" y="12" width="6" height="6" rx="1" />
		</svg>
	)
}

function IconInit() {
	return (
		<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
			<path d="M4 4h6v6H4z" />
			<path d="M14 4h6v6h-6z" />
			<path d="M4 14h6v6H4z" />
			<path d="M14 14h6v6h-6z" />
			<path d="M10 7h4" />
			<path d="M7 10v4" />
			<path d="M17 10v4" />
			<path d="M10 17h4" />
		</svg>
	)
}

function IconPriority() {
	return (
		<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
			<path d="M3 6h18M3 12h12M3 18h6" />
		</svg>
	)
}

function IconUniverse() {
	return (
		<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
			<circle cx="12" cy="12" r="10" />
			<path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
		</svg>
	)
}

function IconDebug() {
	return (
		<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
			<path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z" />
			<path d="M12 8v4l3 3" />
		</svg>
	)
}

// ── Feature data ─────────────────────────────────────────────────────────────

const FEATURES = [
	{
		icon: <IconCycle />,
		title: "Cyclic Dependency Support",
		description:
			"The standout feature of Order. Modules can freely reference each other — no more restructuring your code to avoid circular imports. Order handles the complexity behind the scenes through a metatable-based approach.",
	},
	{
		icon: <IconModule />,
		title: "Effortless Module Loading",
		description: (
			<>
				Replace <code>require()</code> chains with a single call: <code>shared("ModuleName")</code>.
				Resolve modules by name, partial path, or direct instance reference — Order finds them for you.
			</>
		),
	},
	{
		icon: <IconInit />,
		title: "Customizable Init Sequence",
		description:
			"Define your own initialization pipeline. The default Prep → Init pattern gives you a synchronous setup phase followed by an async runtime phase, and you can override or extend this per-task or project-wide.",
	},
	{
		icon: <IconPriority />,
		title: "Task Priority Control",
		description:
			"Set a Priority value on any task to control its position in the load order — higher values go first, negatives last. Gain fine-grained control over startup without tangling dependency chains.",
	},
	{
		icon: <IconUniverse />,
		title: "Multi-Place Universe Support",
		description:
			"First-class support for Roblox game universes. Map Place IDs to named types, then define which Code Groups are active per type — share exactly the right code across your lobby, game servers, and more.",
	},
	{
		icon: <IconDebug />,
		title: "Built-In Developer Tools",
		description:
			"Toggle verbose module loading logs and cyclic-dependency analysis straight from Settings.luau. Silent mode keeps production output clean while keeping Studio output rich.",
	},
]

// ── Code showcase ─────────────────────────────────────────────────────────────

const CODE_SNIPPETS = [
	{
		label: "Loading Modules",
		code: `-- Load a module by name (no path required)
local DataManager = shared("DataManager")

-- Or by partial path for disambiguation
local GetRemote = shared("lib/GetRemote")

-- Or by direct ModuleScript reference
local Util = shared(game.ReplicatedStorage.Shared.Util)`,
	},
	{
		label: "Defining a Task",
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
		label: "Circular Dependencies",
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

// ── Components ────────────────────────────────────────────────────────────────

function Feature({ icon, title, description }) {
	return (
		<div className={clsx("col col--4")}>
			<div className={styles.featureCard}>
				<div className={styles.featureIcon}>{icon}</div>
				<div className={styles.featureBody}>
					<h3>{title}</h3>
					<p>{description}</p>
				</div>
			</div>
		</div>
	)
}

function HomepageFeatures() {
	return (
		<section className={styles.features}>
			<div className="container">
				<h2 className={styles.sectionHeading}>Why Order?</h2>
				<p className={styles.sectionSubheading}>
					Order removes the barriers between modules so you can focus on building great experiences.
				</p>
				<div className="row">
					{FEATURES.map((props, idx) => (
						<Feature key={idx} {...props} />
					))}
				</div>
			</div>
		</section>
	)
}

function CodeShowcase() {
	const [active, setActive] = React.useState(0)

	return (
		<section className={styles.codeShowcase}>
			<div className="container">
				<h2 className={styles.sectionHeading}>Clean, Intuitive API</h2>
				<p className={styles.sectionSubheading}>
					Order's API is designed to stay out of your way. Here's how common patterns look in practice.
				</p>
				<div className={styles.codePanel}>
					<div className={styles.codeTabs}>
						{CODE_SNIPPETS.map((s, i) => (
							<button
								key={i}
								className={clsx(styles.codeTab, { [styles.codeTabActive]: active === i })}
								onClick={() => setActive(i)}
							>
								{s.label}
							</button>
						))}
					</div>
					<div className={styles.codeBlockWrapper}>
						<CodeBlock language="lua">{CODE_SNIPPETS[active].code}</CodeBlock>
					</div>
				</div>
			</div>
		</section>
	)
}

function HomepageHeader() {
	const { siteConfig } = useDocusaurusContext()
	const bannerImage = siteConfig.customFields?.bannerImage
	const hasBannerImage = !!bannerImage
	const heroBannerStyle = hasBannerImage ? { backgroundImage: `url("${bannerImage}")` } : null

	const titleClassName = clsx("hero__title", {
		[styles.titleOnBannerImage]: hasBannerImage,
	})
	const taglineClassName = clsx("hero__subtitle", {
		[styles.taglineOnBannerImage]: hasBannerImage,
	})

	return (
		<header className={clsx("hero", styles.heroBanner)} style={heroBannerStyle}>
			<div className="container">
				<h1 className={titleClassName}>{siteConfig.title}</h1>
				<p className={taglineClassName}>{siteConfig.tagline}</p>
				<p className={styles.heroDescription}>
					A configurable module-loader framework for Roblox featuring fast lookups,
					cyclic dependency support, and a fully customizable initialization pipeline.
				</p>
				<div className={styles.buttons}>
					<Link className="button button--primary button--lg" to="/docs/intro">
						Get Started →
					</Link>
					<Link className="button button--secondary button--lg" to="/api">
						API Reference
					</Link>
				</div>
				<div className={styles.heroMeta}>
					<span className={styles.heroBadge}>v3.0.0</span>
					<span className={styles.heroBadge}>Roblox</span>
					<span className={styles.heroBadge}>Luau</span>
					<a
						className={clsx(styles.heroBadge, styles.heroBadgeLink)}
						href="https://github.com/atomic-horizon/order"
						target="_blank"
						rel="noopener noreferrer"
					>
						GitHub ↗
					</a>
				</div>
			</div>
		</header>
	)
}

const DESCRIPTION =
	"A configurable module-loader framework for Roblox featuring fast lookups, cyclic dependency support, and a fully customizable initialization pipeline."
const TITLE = "Order"

export default function Home() {
	return (
		<>
			<Layout title={TITLE} description={DESCRIPTION}>
				<HomepageHeader />
				<main>
					<HomepageFeatures />
					<CodeShowcase />
				</main>
			</Layout>
			<Head>
				<title>{TITLE}</title>
				<meta property="og:type" content="website" />
				<meta property="og:title" content={TITLE} />
				<meta property="og:description" content={DESCRIPTION} />
				<meta property="og:image" content="https://atomic-horizon.github.io/order/img/embed_banner.png" />
				<meta property="twitter:domain" content="atomic-horizon.github.io" />
				<meta property="twitter:url" content="https://atomic-horizon.github.io/order/" />
				<meta name="twitter:image" content="https://atomic-horizon.github.io/order/img/embed_banner.png" />
			</Head>
		</>
	)
}
