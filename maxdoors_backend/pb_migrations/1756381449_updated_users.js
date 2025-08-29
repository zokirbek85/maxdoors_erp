/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "deleteRule": "@request.auth.record.role = \"admin\"",
    "listRule": "@request.auth.id != \"\" && @request.auth.record.is_active = true",
    "updateRule": "@request.auth.record.role = \"admin\"",
    "viewRule": "@request.auth.id != \"\" && @request.auth.record.is_active = true"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "deleteRule": "id = @request.auth.id",
    "listRule": "@request.auth.id != \"\" && @request.auth.record.is_active = true\n",
    "updateRule": "id = @request.auth.id",
    "viewRule": "id = @request.auth.id"
  }, collection)

  return app.save(collection)
})
