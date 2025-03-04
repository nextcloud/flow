<!--
  - SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: MIT
-->
<template>
	<div class="iframe-ui-viewer">
		<iframe
			v-show="!error && !loading"
			id="flow-iframe"
			ref="iframe"
			:name="'flow-iframe'"
			class="flow__iframe"
			allow="clipboard-read *; clipboard-write *"
			:src="iframeSrc" />
		<NcLoadingIcon v-if="loading" :size="48" />
		<NcEmptyContent
			v-if="error && !loading"
			:name="t('flow', 'Failed to load service iframe')"
			:description="t('flow', 'Please try again.')">
			<template #icon>
				<AlertCircleIcon :size="20" />
			</template>
		</NcEmptyContent>
	</div>
</template>

<script>
import { generateUrl } from '@nextcloud/router'

import NcEmptyContent from '@nextcloud/vue/dist/Components/NcEmptyContent.js'
import AlertCircleIcon from 'vue-material-design-icons/AlertCircle.vue'
import NcLoadingIcon from '@nextcloud/vue/dist/Components/NcLoadingIcon.js'

import { APP_API_PROXY_URL_PREFIX, EX_APP_ID } from '../constants/AppAPI.js'

export default {
	name: 'IframeView',
	components: {
		NcEmptyContent,
		AlertCircleIcon,
		NcLoadingIcon,
	},
	data() {
		return {
			error: null,
			loading: true,
			iframeSrc: generateUrl(`${APP_API_PROXY_URL_PREFIX}/${EX_APP_ID}/`, {}, { noRewrite: true }),
		}
	},
	mounted() {
		const timeout = setTimeout(() => {
			this.error = true
			this.loading = false
		}, 10000)
		this.$refs.iframe.addEventListener('load', (event) => {
			console.debug('iframe service loaded', event)
			this.loading = false
			clearTimeout(timeout)
		})
		this.$refs.iframe.addEventListener('error', (event) => {
			console.debug('iframe service error', event)
			this.error = true
			this.loading = false
		})
	},
}
</script>

<style>
.iframe-ui-viewer {
	display: flex;
	justify-content: center;
	align-items: center;
	height: 100%;
}

.flow__iframe {
	width: 100%;
	height: 100%;
	flex-grow: 1;
}
</style>
