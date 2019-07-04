#COMMENTAIRE
.comment "commentaire du fichier"

#COMMENTAIRE
#COMMENTAIRE
#COMMENTAIRE
.name	"test d'un name"

label1:

label2:

label3:

fork: fork %:life

load: or %:fork,r2,r3

life: and %:load,r2,r1

ldi 3, %4, r1
