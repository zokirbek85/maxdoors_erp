/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_654718158")

  // update collection data
  unmarshal({
    "createRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_654718158")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\""
  }, collection)

  return app.save(collection)
})
