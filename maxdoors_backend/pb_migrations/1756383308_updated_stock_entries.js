/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3714752023")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "deleteRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "updateRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "viewRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\" || @request.auth.record.role = \"owner\")"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3714752023")

  // update collection data
  unmarshal({
    "createRule": null,
    "deleteRule": null,
    "updateRule": null,
    "viewRule": null
  }, collection)

  return app.save(collection)
})
