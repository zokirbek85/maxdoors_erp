/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_2642033611")

  // update field
  collection.fields.addAt(5, new Field({
    "hidden": false,
    "id": "select1001949196",
    "maxSelect": 1,
    "name": "reason",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "select",
    "values": [
      "purchase",
      "return_in",
      "order_pack",
      "order_cancel",
      "defect_in",
      "defect_out",
      "import"
    ]
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2642033611")

  // update field
  collection.fields.addAt(5, new Field({
    "hidden": false,
    "id": "select1001949196",
    "maxSelect": 1,
    "name": "reason",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "select",
    "values": [
      "purchase",
      "return_in",
      "order_pack",
      "order_cancel",
      "defect_in",
      "defect_out"
    ]
  }))

  return app.save(collection)
})
