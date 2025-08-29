/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"manager\"\n)\n",
    "listRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"owner\" ||\n  @request.auth.record.role = \"warehouseman\" ||\n  manager = @request.auth.id ||\n  dealer.assigned_manager = @request.auth.id\n)\n",
    "updateRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"warehouseman\"\n)\n",
    "viewRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"owner\" ||\n  @request.auth.record.role = \"warehouseman\" ||\n  manager = @request.auth.id ||\n  dealer.assigned_manager = @request.auth.id\n)\n"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "createRule": "",
    "listRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"manager\" ||\n  @request.auth.record.role = \"warehouseman\" ||\n  @request.auth.record.role = \"owner\"\n)",
    "updateRule": "@request.auth.record.role = \"admin\" ||\n(@request.auth.record.role = \"manager\" && editable = true) ||\n(@request.auth.record.role = \"warehouseman\" && (status = \"created\" || status = \"packed\"))\n",
    "viewRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"manager\" ||\n  @request.auth.record.role = \"warehouseman\" ||\n  @request.auth.record.role = \"owner\"\n)"
  }, collection)

  return app.save(collection)
})
