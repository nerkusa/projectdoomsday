extends MirnyDistrict
## Мирный · квартал рейдеров — баррикады из лома, лачуги, притон «Дыра», где сидит Шрам.


func _ready() -> void:
	location_id = "mirny_raiders"
	title = "Мирный · квартал рейдеров"
	links = {"ToCenter": ["mirny", "FromRaiders", "Центр"]}
	arrive_thought = "Квартал рейдеров. Баррикады из машин и листов, дым от бочек, на стене — «ШРАМ — ХОЗЯИН». Здесь чужих не любят, но торгуют со всеми."
	super._ready()
