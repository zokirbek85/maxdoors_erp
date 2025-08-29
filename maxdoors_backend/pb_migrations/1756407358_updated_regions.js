/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_859047449")

  // update field
  collection.fields.addAt(2, new Field({
    "hidden": false,
    "id": "geoPoint1542800728",
    "name": "location",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "geoPoint"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_859047449")

  // update field
  collection.fields.addAt(2, new Field({
    "hidden": false,
    "id": "geoPoint1542800728",
    "name": "field",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "geoPoint"
  }))

  return app.save(collection)
})
