const path = require('path')
const webpackConfig = require('@nextcloud/webpack-vue-config')
const webpackRules = require('@nextcloud/webpack-vue-config/rules')
const ESLintPlugin = require('eslint-webpack-plugin')
const StyleLintPlugin = require('stylelint-webpack-plugin')

const buildMode = process.env.NODE_ENV
const isDev = buildMode === 'development'
webpackConfig.devtool = isDev ? 'cheap-source-map' : 'source-map'

webpackConfig.stats = {
	colors: true,
	modules: false,
}

const appId = 'flow'

webpackConfig.entry = {
	main: { import: path.join(__dirname, 'ex_app', 'src', 'main.js'), filename: appId + '-main.js' },
}

webpackConfig.module.rules = Object.values(webpackRules)

webpackConfig.plugins.push(
	new ESLintPlugin({
		extensions: ['js', 'vue'],
		files: 'ex_app/src',
		failOnError: !isDev,
	})
)

webpackConfig.plugins.push(
	new StyleLintPlugin({
		files: 'ex_app/src/**/*.{css,scss,vue}',
		failOnError: !isDev,
	}),
)

webpackConfig.output = {
	path: path.resolve(__dirname, 'ex_app/js'),
}

module.exports = webpackConfig
