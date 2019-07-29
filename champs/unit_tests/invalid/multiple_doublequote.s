#COMMENTAIRE
.name	"test" "d'un name"
.comment "commentaire du fichier"

#COMMENTAIRE
#COMMENTAIRE
#COMMENTAIRE

fork: fork %:li_fe

load: or %:fork,r2,r3

life: and %:load,r2,r1

ldi 3, %4, r1
