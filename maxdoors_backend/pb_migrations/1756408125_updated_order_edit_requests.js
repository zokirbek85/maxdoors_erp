/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3176995872")

  // update collection data
  unmarshal({
    "createRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3176995872")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"manager\"\n"
  }, collection)

  return app.save(collection)
})
