/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_2862527041")

  // update collection data
  unmarshal({
    "createRule": "",
    "deleteRule": "",
    "listRule": "",
    "updateRule": "",
    "viewRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2862527041")

  // update collection data
  unmarshal({
    "createRule": null,
    "deleteRule": null,
    "listRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"owner\")",
    "updateRule": null,
    "viewRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"owner\")"
  }, collection)

  return app.save(collection)
})
