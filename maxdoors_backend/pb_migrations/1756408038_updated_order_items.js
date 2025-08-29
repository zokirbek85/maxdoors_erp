/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_2456927940")

  // update collection data
  unmarshal({
    "createRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2456927940")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.record.role = \"admin\" ||\n(@request.auth.record.role = \"manager\" && order.editable = true)\n"
  }, collection)

  return app.save(collection)
})
