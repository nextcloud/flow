/**
 * SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: MIT
 */

import './bootstrap.js'
import Vue from 'vue'
import App from './App.vue'
import { Tooltip } from '@nextcloud/vue'

Vue.directive('tooltip', Tooltip)

export default new Vue({
	el: '#content',
	render: h => h(App),
})
