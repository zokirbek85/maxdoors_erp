/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_654718158")

  // update collection data
  unmarshal({
    "deleteRule": "",
    "listRule": "",
    "updateRule": "",
    "viewRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_654718158")

  // update collection data
  unmarshal({
    "deleteRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "listRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\" || @request.auth.record.role = \"owner\")",
    "updateRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "viewRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\" || @request.auth.record.role = \"owner\")"
  }, collection)

  return app.save(collection)
})
