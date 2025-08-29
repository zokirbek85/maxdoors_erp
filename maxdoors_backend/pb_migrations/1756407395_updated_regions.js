/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_859047449")

  // update collection data
  unmarshal({
    "createRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_859047449")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.record.role = \"admin\""
  }, collection)

  return app.save(collection)
})
