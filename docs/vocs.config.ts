import { defineConfig } from 'vocs/config'
import { sidebar } from './vocs.sidebar'

export default defineConfig({
  title: 'DEX Project Documentation',

  basePath: '/DEX-project',

  renderStrategy: 'full-static',

  editLink: {
    link: (path) =>
      `https://github.com/tarasyk9/DEX-project/edit/main/docs/src/pages/${path}`,
    text: 'Suggest changes to this page',
  },

  sidebar,
})
