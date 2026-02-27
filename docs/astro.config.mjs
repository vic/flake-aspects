// @ts-check
import { defineConfig, fontProviders } from 'astro/config';
import starlight from '@astrojs/starlight';

import mermaid from 'astro-mermaid';
import catppuccin from "@catppuccin/starlight";

// https://astro.build/config
export default defineConfig({
	experimental: {
		fonts: [
			{
				provider: fontProviders.google(),
				name: "Victor Mono",
				cssVariable: "--sl-font",
			},
		],
	},
	integrations: [
		mermaid({
			theme: 'forest',
			autoTheme: true
		}),
		starlight({
			title: 'flake-aspects',
			sidebar: [
				{
					label: 'flake-aspects',
					items: [
						{ label: 'Home', slug: '' },
						{ label: 'Overview', slug: 'overview' },
						{ label: 'Motivation', slug: 'motivation' },
					],
				},
				{
					label: 'Concepts',
					items: [
						{ label: 'Transpose', slug: 'concepts/transpose' },
						{ label: 'Aspects & Resolution', slug: 'concepts/aspects' },
						{ label: 'Providers & Fixpoint', slug: 'concepts/providers' },
					],
				},
				{
					label: 'Guides',
					items: [
						{ label: 'With flake-parts', slug: 'guides/flake-parts' },
						{ label: 'Without Flakes', slug: 'guides/standalone' },
						{ label: 'Cross-Aspect Dependencies', slug: 'guides/dependencies' },
						{ label: 'Parametric Aspects', slug: 'guides/parametric' },
						{ label: '__functor Override', slug: 'guides/functor' },
						{ label: 'Forward Across Classes', slug: 'guides/forward' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'API', slug: 'reference/api' },
						{ label: 'Type System', slug: 'reference/types' },
						{ label: 'Tests', slug: 'reference/tests' },
					],
				},
				{
					label: 'Project',
					items: [
						{ label: 'Contributing', slug: 'contributing' },
						{ label: 'Sponsor', slug: 'sponsor' },
					],
				},
			],
			components: {
				Sidebar: './src/components/Sidebar.astro',
				Footer: './src/components/Footer.astro',
				SocialIcons: './src/components/SocialIcons.astro',
				PageSidebar: './src/components/PageSidebar.astro',
			},
			plugins: [
				catppuccin({
					dark: { flavor: "macchiato", accent: "mauve" },
					light: { flavor: "latte", accent: "mauve" },
				}),
			],
			editLink: {
				baseUrl: 'https://github.com/vic/flake-aspects/edit/main/docs/',
			},
			customCss: [
				'./src/styles/custom.css'
			],
		}),
	],
});
