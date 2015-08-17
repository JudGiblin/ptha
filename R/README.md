rptha
-----

rptha is the main workhorse R package. To build it, go inside 'rptha', start R, and do:

    source('build_package.R')

This will make an R package file in the directory above the package, which can be installed on the command line with:

    sudo R CMD INSTALL rptha_XXXXX.tar.gz

where the XXXX are adapted to match the file name.

If the above fails because you are missing packages, then try running this prior to the install to get the required packages:

    install.packages(c('sp', 'rgdal', 'rgeos', 'FNN', 'raster', 'minpack.lm', 'geosphere', 'rgl', 'testthat', 'devtools'))


source_contours_2_unit_sources
------------------------------

This contains example code to make tsunami unit sources from source contours