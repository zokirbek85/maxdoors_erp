/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

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
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"manager\"\n)\n",
    "deleteRule": "@request.auth.record.role = \"admin\"",
    "listRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"owner\" ||\n  @request.auth.record.role = \"warehouseman\" ||\n  manager = @request.auth.id ||\n  dealer.assigned_manager = @request.auth.id\n)\n",
    "updateRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"warehouseman\"\n)\n",
    "viewRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"owner\" ||\n  @request.auth.record.role = \"warehouseman\" ||\n  manager = @request.auth.id ||\n  dealer.assigned_manager = @request.auth.id\n)\n"
  }, collection)

  return app.save(collection)
})
