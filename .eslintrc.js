/**
 * SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: MIT
 */

module.exports = {
	globals: {
		appVersion: true
	},
	parserOptions: {
		requireConfigFile: false
	},
	extends: [
		'@nextcloud'
	],
	rules: {
		'jsdoc/require-jsdoc': 'off',
		'jsdoc/tag-lines': 'off',
		'vue/first-attribute-linebreak': 'off',
		'import/extensions': 'off'
	}
}
