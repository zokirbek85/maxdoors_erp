/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_631030571")

  // update collection data
  unmarshal({
    "deleteRule": "",
    "updateRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_631030571")

  // update collection data
  unmarshal({
    "deleteRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "updateRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\""
  }, collection)

  return app.save(collection)
})
