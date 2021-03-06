library(maps)
library(rgdal)

setwd('~/gis/country')
country = readOGR('country.shp','country')

setwd('~/maxent/spat')

dat = read.csv('./data/empir_geo_coords.csv')
head(dat)

apply(dat[,-1], 2, range)

map('world', xlim=c(-125, -64), ylim=c(7, 45))
map('state', add=TRUE)
#axis(side=1)
#axis(side=2)
points(dat[,3], dat[,2], col='dodgerblue', pch=19, cex=1.25)

pdf('./figs/global_map.pdf')
  plot(country, xlim=c(-125, -64), ylim=c(7, 45))
  points(dat[,3], dat[,2], col='dodgerblue', pch=19, cex=1.25)
dev.off()

## blow up NC
data(us.cities)
pdf('./figs/nc_map.pdf')
  map('county', c('north carolina,orange', 'north carolina,durham'))
  points(dat[,3], dat[,2], col='dodgerblue', pch=19, cex=1.25)
  map.cities(us.cities, country="NC")
dev.off()

## blow up Panama
map('world', 'panama')
axis(side=1)
axis(side=2)

pdf('./figs/panama_map.pdf')
  plot(country, xlim=c(-80, -79), ylim=c(7, 10))
  points(dat[,3], dat[,2], col='dodgerblue', pch=19, cex=1.25)
dev.off()

## To do
## output an OGR layer for google earth this way we can get quick satelitte
## imagry
