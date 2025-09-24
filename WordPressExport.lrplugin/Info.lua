--[[----------------------------------------------------------------------------

Info.lua
WordPress Export Plugin für Lightroom Classic

--------------------------------------------------------------------------------

Definiert die Plugin-Metadaten und Export-Service für den direkten Upload
in die WordPress Mediathek über die REST API.

------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0,

	LrToolkitIdentifier = 'com.dermatz.lightroom.export.wordpress',
	LrPluginName = 'WordPress Export',

	LrExportServiceProvider = {
		title = "WordPress Upload",
		file = 'ExportServiceProvider.lua',
	},

	LrMetadataProvider = 'MetadataDefinition.lua',

	LrPluginInfoUrl = "https://dermatz.de/produkt/lightroom-classic-to-wordpress-exporter",

	-- Plugin Manager Integration
	LrPluginInfoProvider = 'PluginManager.lua',

	-- Menü-Integration für Plugin-Verwaltung
	LrToolkitVersion = 1,

	VERSION = { major=1, minor=2, revision=0, },

}
