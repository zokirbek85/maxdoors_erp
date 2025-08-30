/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1682207476")

  // update collection data
  unmarshal({
    "updateRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1682207476")

  // update collection data
  unmarshal({
    "updateRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\""
  }, collection)

  return app.save(collection)
})
