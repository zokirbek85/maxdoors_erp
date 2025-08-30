/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_4153672788")

  // update collection data
  unmarshal({
    "deleteRule": "",
    "listRule": "",
    "updateRule": "",
    "viewRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_4153672788")

  // update collection data
  unmarshal({
    "deleteRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "listRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"owner\"\n)\n  ",
    "updateRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "viewRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"owner\"\n)\n"
  }, collection)

  return app.save(collection)
})
