--[[----------------------------------------------------------------------------

MetadataDefinition.lua
Metadata Definition für WordPress Export

--------------------------------------------------------------------------------

Definiert zusätzliche Metadatenfelder für WordPress-spezifische Informationen.

------------------------------------------------------------------------------]]

return {

	metadataFieldsForPhotos = {
		{
			id = 'wordpressMediaId',
			title = 'WordPress Media ID',
			dataType = 'string',
			searchable = true,
			browsable = true,
		},
		{
			id = 'wordpressUploadDate',
			title = 'WordPress Upload Date',
			dataType = 'string',
			searchable = true,
			browsable = true,
		},
	},

	schemaVersion = 1,

}
