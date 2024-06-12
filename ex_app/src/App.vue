<template>
	<NcContent app-name="windmill_app">
		<NcAppContent>
			<IframeView />
		</NcAppContent>
	</NcContent>
</template>

<script>
import NcContent from '@nextcloud/vue/dist/Components/NcContent.js'
import NcAppContent from '@nextcloud/vue/dist/Components/NcAppContent.js'
import IframeView from './views/IframeView.vue'

export default {
	name: 'App',
	components: {
		NcContent,
		NcAppContent,
		IframeView,
	},
}
</script>
