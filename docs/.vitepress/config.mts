import { defineConfig } from 'vitepress'

// Docs for OrdaenCore.UI. Run from docs/: `npm install`, then `npm run dev`.
export default defineConfig({
  title: 'Ordaen UI',
  description: 'The declarative UI framework in Ordaen Core, for WoW Forever addons.',
  cleanUrls: true,
  lastUpdated: true,
  markdown: {
    theme: { light: 'github-light', dark: 'github-dark' },
  },
  themeConfig: {
    nav: [
      { text: 'Guide', link: '/guide/quick-start', activeMatch: '/guide/' },
      { text: 'Reference', link: '/reference/api', activeMatch: '/reference/' },
      { text: 'Roadmap', link: '/roadmap' },
    ],
    sidebar: [
      {
        text: 'Getting started',
        items: [
          { text: 'Introduction', link: '/' },
          { text: 'Quick start', link: '/guide/quick-start' },
        ],
      },
      {
        text: 'Concepts',
        items: [
          { text: 'Blocks and elements', link: '/guide/blocks' },
          { text: 'Layout', link: '/guide/layout' },
          { text: 'Text', link: '/guide/text' },
          { text: 'Tooltips', link: '/guide/tooltips' },
          { text: 'Themes', link: '/guide/themes' },
        ],
      },
      {
        text: 'Under the hood',
        items: [
          { text: 'Architecture', link: '/guide/architecture' },
          { text: 'Performance', link: '/guide/performance' },
          { text: 'Testing', link: '/guide/testing' },
        ],
      },
      {
        text: 'Reference',
        items: [
          { text: 'API', link: '/reference/api' },
          { text: 'Block format', link: '/reference/format' },
          { text: 'Settings manifest', link: '/reference/settings' },
          { text: 'Themes and roles', link: '/reference/theme' },
        ],
      },
      { text: 'Roadmap', link: '/roadmap' },
    ],
    outline: { level: [2, 3] },
    search: { provider: 'local' },
    footer: {
      message: 'Describes OrdaenCore.UI as built on develop. Planned parts are marked as such.',
    },
  },
})
