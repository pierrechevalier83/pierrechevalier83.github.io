#!/bin/bash
#Builds the whole site
buildpage() {
	#build a html page, given a title, markdown source, output file
	compose "$1" "$2" > "$3"
	tidy -m -q "$3"
}
compose() {
	sed -e 's/%title/'"$1/" < src/header
	kramdown --no-auto-ids --entity-output :symbolic "$2"
	cat src/footer
}
articlelist(){
	for article in src/articles/"$1"/*.md
	do
		echo $article
		mkdir -pv "articles/$1"
		title=$(sed -ne 's/([^\)]*)//g' -e's/^## *\([^#]\)/\1/p' <"${article}")
		printf "%s\n" "- [$title](articles/$1/$(basename -s .md $article).html)" >> src/articles.md
		buildpage "$(echo $title | tr '[:upper:]' '[:lower:]')" "$article" "articles/$1/$(basename -s .md $article).html"
	done
}

articlelist '.'
while read category
do
	catname=$(echo "$category" | cut -f1 -d' ')
	catdesc=$(echo "$category" | cut -f1 -d' ' --complement)
	printf "\n%s\n\n" "$catdesc" >> src/articles.md
	articlelist "$catname"
done < src/articles/categories

buildpage "Pierrec's tech" src/index.md index.html
buildpage "Pierrec's tech - Code" src/code.md code.html
buildpage "Pierrec's tech - Learning" src/learning.md learning.html
buildpage "Pierrec's tech - Hardware" src/hardware.md hardware.html
