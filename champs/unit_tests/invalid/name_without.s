#COMMENTAIRE
.comment	"test d'un comment"


#COMMENTAIRE

fork: fork %:li3_fe

load: or %:fork,r2,r3

li3_fe: and %:load,r2,r1

ldi 3, %4, r1
