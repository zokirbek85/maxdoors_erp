/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3176995872")

  // update collection data
  unmarshal({
    "deleteRule": "",
    "listRule": "",
    "updateRule": "",
    "viewRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3176995872")

  // update collection data
  unmarshal({
    "deleteRule": "@request.auth.record.role = \"admin\"",
    "listRule": "@request.auth.id != \"\"",
    "updateRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"warehouseman\"\n",
    "viewRule": "@request.auth.id != \"\""
  }, collection)

  return app.save(collection)
})
