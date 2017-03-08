# Below is a note on a strange netcdf bug that I encountered while developing
# this. The problem turned out to be associated with netcdf-4.1.3 (only,
# apparently). I worked around it by compiling R's ncdf4 library with a more
# recent version of netcdf (which coincidently I'd build earlier, for working with opencoarrays)
##  
##  # I can access ncdf files via opendap. However, there is a strange bug that appears when indexing subsets.
##  
##  library(ncdf4)
##  fid = nc_open('http://dapds00.nci.org.au/thredds/dodsC/fj6/PTHA/AustPTHA/v2017/SOURCE_ZONES/puysegur/TSUNAMI_UNIT_SOURCE/unit_source_tsunami/RUN_20161121104520_puysegur_1_1/RUN_ID100001_20161123_082248.005/Gauges_data_ID100001.nc')
##  
##  # This works -- note that start[2] is not = 1 (start[2] corresponds to the tide gauge index)
##  stage = ncvar_get(fid, 'stage', start=c(1,2), count=c(-1,1))
##  # If start[2] = 1, then it hangs on my machine, and on an ubuntu 14.04 virtual machine I tested. However, the command works on the NCI.
##  # stage = ncvar_get(fid, 'stage', start=c(1,1), count=c(-1,1))
##  
##  # Further, ncks seems to HANG when retrieving the first tide gauge index
##  ncks -d station,0 -v stage 'http://dapds00.nci.org.au/thredds/dodsC/fj6/PTHA/AustPTHA/v2017/SOURCE_ZONES/puysegur/TSUNAMI_UNIT_SOURCE/unit_source_tsunami/RUN_20161121104520_puysegur_1_1/RUN_ID100001_20161123_082248.005/Gauges_data_ID100001.nc'
##  # See this related bug!
##  https://sourceforge.net/p/nco/bugs/57/
##  # That link says it's only on netcdf version 4.1.3 -- that is the default ubuntu 14.04 version.
##  # So I re-installed the ncdf4 package in R, using the following commands to use my gcc 6.1 updated ncdf install:
##  #
##  sudo R CMD INSTALL --configure-args='--with-nc-config=/home/gareth/Code_Experiments/alternate_compiler_lib/gcc_6.1/netcdf/install/bin/nc-config' ncdf4
##  # Actually, I also set my PATH, C_INCLUDE_PATH, and LD_LIBRARY_PATH to point to the associated bin/include/lib dirs respectively -- but that might not have done anything.
##  


suppressPackageStartupMessages(library(ncdf4))
suppressPackageStartupMessages(library(rptha))

get_netcdf_gauge_index_matching_ID<-function(netcdf_file, gauge_ID){

    fid = nc_open(netcdf_file, readunlim=FALSE)

    point_ids = ncvar_get(fid, 'gaugeID')

    closest_ID = gauge_ID * NA

    for(i in 1:length(gauge_ID)){
        # The netcdf file stores the IDs as floats, which implies some
        # rounding. 
        closest_ID[i] = which.min(abs(point_ids - gauge_ID[i]))
    }

    if(any(abs(gauge_ID - point_ids[closest_ID]) > 0.05)){
        kk = which.max(abs(gauge_ID - point_ids[closest_ID]))
        print(gauge_ID[kk])
        print(point_ids[closest_ID[kk]])
        stop('Provided ID differs from nearest ID by > 0.05')
    }
    
    nc_close(fid)

    return(closest_ID)
}

#'
#' Get the 'input_stage_raster' attribute from the tide gauge netcdf files. This
#' helps us match netcdf files to unit sources
#'
#' @param netcdf_file name of netcdf tide gauge file
#' @return value of the input_stage_raster attribute of the netcdf file
#' @export
get_netcdf_attribute_initial_stage_raster<-function(netcdf_file){

    fid = nc_open(netcdf_file, readunlim=FALSE)
    myatt = ncatt_get(fid, varid=0, 'input_stage_raster')$value
    nc_close(fid)
    return(myatt)
}

#'
#' Get lon/lat/depth/gaugeID from gauges in netcdf file
#' 
#' @param netcdf_file name of netdf tide gauge file
#' @param indices_of_subset integer vector with rows of the table to return. By
#' default return all rows
#' @return data.frame with lon, lat, elev, gaugeID
#' @export
get_netcdf_gauge_locations<-function(netcdf_file, indices_of_subset = NULL){

    fid = nc_open(netcdf_file, readunlim=FALSE)

    gauge_ids = ncvar_get(fid, 'gaugeID')
    lon = ncvar_get(fid, 'lon')
    lat = ncvar_get(fid, 'lat')
    elev = ncvar_get(fid, 'elevation0')

    if(!is.null(indices_of_subset)){
        gauge_ids = gauge_ids[indices_of_subset]
        lon = lon[indices_of_subset]
        lat = lat[indices_of_subset]
        elev = elev[indices_of_subset]
    }

    nc_close(fid)

    gauge_data = data.frame(lon=lon, lat=lat, elev=elev, gaugeID = gauge_ids)

    return(gauge_data)
}

#' Extract the time vector from a netcdf file
#'
get_netcdf_gauge_output_times<-function(netcdf_file){

    fid = nc_open(netcdf_file, readunlim=FALSE)
    times = ncvar_get(fid, 'time')
    nc_close(fid)
    return(times)
}

#'
#' Find the indices of gauges in a netcdf file which are nearest to 
#' a matrix of lon/lat coordinates.
#'
#' @param netcdf_file name of netcdf tide gauge file
#' @param lonlat matrix with 2 columns containing lon/lat coordinates along rows
#' @return integer vector, containing the indices of points in the tide gauge
#' file which are nearest each point of lonlat
#' @export
get_netcdf_gauge_indices_near_points<-function(netcdf_file, lonlat){

    gauge_data = get_netcdf_gauge_locations(netcdf_file)
    lg = length(gauge_data[,1])
  
    inds = rep(NA, length(lonlat[,1]))  

    for(i in 1:length(lonlat[,1])){
        suppressWarnings({
        inds[i] = which.min(distHaversine(
            cbind(gauge_data$lon, gauge_data$lat), 
            cbind(rep(lonlat[i,1], lg), rep(lonlat[i,2], lg))))
        })
    }

    return(inds)
}

#'
#' This code tests that netcdf gauge indices near points is working
#' 
.test_get_netcdf_gauge_indices_near_points<-function(netcdf_file){

    gauge_points = get_netcdf_gauge_locations(netcdf_file)

    test_indices = sample(1:length(gauge_points[,1]), size=10, replace=TRUE)

    derived_indices = get_netcdf_gauge_indices_near_points(netcdf_file, gauge_points[test_indices,1:2])

    # It is possible that derived_indices != test_indices, if there are
    # repeated lon/lat points in the gauges
    #if(all(derived_indices == test_indices)){
    if(all(gauge_points[derived_indices,1:2] == gauge_points[test_indices, 1:2])){
        print('PASS')
    }else{
        print('FAIL')
    }

}

#' Find indices of gauges in netcdf file which are inside a polygon
#'
#' @param netcdf_file file with netcdf tide gauge data
#' @param region_poly SpatialPolygons object, inside which we want to know the
#' indices of all gauges.
#' @param return integer vector with indices of gauges inside the polygon
#' @export
get_netcdf_gauge_indices_in_polygon<-function(netcdf_file, region_poly){

    gauge_points = get_netcdf_gauge_locations(netcdf_file)

    coords = cbind(gauge_points$lon, gauge_points$lat)
    coords_sp = SpatialPoints(coords, 
        proj4string=CRS(proj4string(region_poly)))

    indices_of_subset = which(!is.na(over(coords_sp, region_poly)))
    if(length(indices_of_subset) == 0) stop('No coordinates in region_poly') 

    return(indices_of_subset)
}

#' Test of the above routine.
.test_get_netcdf_gauge_indices_in_polygon<-function(netcdf_file){

    gauge_points = get_netcdf_gauge_locations(netcdf_file)

    test_inds = c(1, length(gauge_points[,1]))

    test_poly = gBuffer(SpatialPoints(gauge_points[test_inds,1:2]), width=1.0e-03)
    proj4string(test_poly) = '+init=epsg:4326'
   
    inside_points = get_netcdf_gauge_indices_in_polygon(netcdf_file, test_poly)

    if(all(sort(test_inds) == sort(inside_points))){
        print('PASS')
    }else{
        print('FAIL')
    }
}

#' Convenience function to sort the netcdf tide gauge files in the same order as
#' the unit_source_statistics table. This is required for the unit-source
#' summation.
#'
#' @param unit_source_statistics data.frame with unit_source_statistics summary information,
#' typically derived as output from \code{rptha::discretized_source_summary_statistics}
#' @param netcdf_tide_gauge_files vector of netcdf tide gauge files. There should be at least one
#' file corresponding to each row of the unit_source_statistics. If there are more than one, then
#' only the first is used. There can also be extraneous files, which will be ignored.
#' @param character vector of netcdf_tide_gauge_files, ordered to correspond to
#' rows of unit_source_statistics
#' @export
sort_tide_gauge_files_by_unit_source_table<-function(
    unit_source_statistics,
    netcdf_tide_gauge_files){

    tide_gauge_rasters = sapply(netcdf_tide_gauge_files, 
        get_netcdf_attribute_initial_stage_raster)

    unit_source_to_tg = match(unit_source_statistics$initial_condition_file, 
        tide_gauge_rasters)

    if(any(is.na(unit_source_to_tg))){
        stop('Some initial condition files are not matching a corresponding tide gauge netcdf attribute')
    }

    return(netcdf_tide_gauge_files[unit_source_to_tg])
}

#' Read flow time-series from the tide gauges netcdf file. 
#'
#' Optionally only read a subset of the flow time-series. Note that depending on 
#' the order of dimensions in the netcdf file, it may be more
#' time-efficient to read all the flow variables and then subset, or to just read
#' the subset
#'
#' @param netcdf_file filename
#' @param indices_of_subset if not NULL, then a vector of integer indices
#' corresponding to the gauges at which flow values are extracted
#' @param flow_and_attributes_only logical. If TRUE, then only read the flow
#' and the file attributes (other variables will be set to NULL). This can be
#' useful for efficiency
#' @param all_flow_variables logical. If TRUE, return an array
#' flow_time_series[i,j,k] with stage, uh, vh corresponding to k=1, 2, 3 resp. 
#' Otherwise return a matrix flow_time_series[i,j] containing just stage.
#' @return list containing a matrix of flow values, netcdf attributes,
#' gaugeIDs, and the value of indices_of_subset. FIXME: Consider returning
#' elevation as well
#' @export
#'
get_flow_time_series_SWALS<-function(netcdf_file, indices_of_subset=NULL,  
    flow_and_attributes_only=TRUE, all_flow_variables=TRUE){

    fid = nc_open(netcdf_file, readunlim=FALSE)

    # Get all 'global' attributes in the netcdf file. This allows sanity checks
    # on book_keeping, since the attributes include e.g. references to the unit
    # source initial conditions.
    run_atts = ncatt_get(fid, varid=0)

    if(!flow_and_attributes_only){
        gauge_ids = ncvar_get(fid, 'gaugeID')
        lat = ncvar_get(fid, 'lat')
        lon = ncvar_get(fid, 'lon')
        elev = ncvar_get(fid, 'elevation0')
    }else{
        # Don't bother reading other gauge information
        gauge_ids = NULL
        lat = NULL
        lon = NULL
        elev = NULL
    }

    # Get the names of the dimensions of stage -- this helps us determine
    # whether we can read the stage efficiently at single stations
    stage_dim1 = fid$var$stage$dim[[1]]$name
    stage_dim2 = fid$var$stage$dim[[2]]$name

    if(stage_dim1 == 'station'){
        # Read all stages, even if we only want a subset, because experience
        # suggests it is faster. This is because time is the 'slowly varying'
        # dimension, so we have to read through the entire file regardless.
        stages = ncvar_get(fid, 'stage')
        # Do subsetting if required
        if(!is.null(indices_of_subset)){
            stages = stages[indices_of_subset,,drop=FALSE]
            if(!flow_and_attributes_only){
                gauge_ids = gauge_ids[indices_of_subset]
                lon = lon[indices_of_subset]
                lat = lat[indices_of_subset]
                elev = elev[indices_of_subset]
            }
        }

        if(all_flow_variables){
            # Get x flux variable
            uhs = ncvar_get(fid, 'uh')
            if(!is.null(indices_of_subset)) uhs = uhs[indices_of_subset,,drop=FALSE]

            # Get y flux variable
            vhs = ncvar_get(fid, 'vh')
            if(!is.null(indices_of_subset)) vhs = vhs[indices_of_subset,,drop=FALSE]
        }

    }else{
	# In this case, the file has time varying quickly, which permits
	# efficient single-station access, so long as indices_of_subset is
	# continuous
        stopifnot(stage_dim1 == 'time')

        if(is.null(indices_of_subset)){
            # We want to read all stages
            read_all_stages = TRUE
        }else{
            # We only want a subset of the stages, so we might
            # be able to read efficiently
            if((length(indices_of_subset) > 1)){
                if(max(diff(indices_of_subset)) == 1){
                    # We can read efficiently
                    read_all_stages = FALSE
                }else{
		    # The stage indices are not consecutive, so we can't do the
		    # read efficiently
                    read_all_stages = TRUE
                }
            }else{
                # Only reading one station, so we can do it efficiently
                read_all_stages = FALSE
            }
        }

        if(read_all_stages){
	    # Take the transpose of the stages for consistency with the case
	    # when time is an unlimited dimension
            stages = t(ncvar_get(fid, 'stage'))
            if(!is.null(indices_of_subset)) stages = stages[indices_of_subset,,drop=FALSE]

            if(all_flow_variables){
                # Get x flux variable
                uhs = ncvar_get(fid, 'uh')
                if(!is.null(indices_of_subset)) uhs = uhs[indices_of_subset,,drop=FALSE]

                # Get y flux variable
                vhs = ncvar_get(fid, 'vh')
                if(!is.null(indices_of_subset)) vhs = vhs[indices_of_subset,,drop=FALSE]
            }
        }else{
	    # Efficient reading is possible, since indices_of_subset is
	    # continuous Take the transpose of the stages for consistency with
	    # the case when time is an unlimited dimension
            stages = t(ncvar_get(fid, 'stage', 
                start = c(1, indices_of_subset[1]), 
                count=c(-1, length(indices_of_subset))))

            if(all_flow_variables){
                uhs = t(ncvar_get(fid, 'uh', 
                    start = c(1, indices_of_subset[1]), 
                    count=c(-1, length(indices_of_subset))))
                vhs = t(ncvar_get(fid, 'vh', 
                    start = c(1, indices_of_subset[1]), 
                    count=c(-1, length(indices_of_subset))))
            }
                
        }

        # We still might have to subset the other variables
        if((!flow_and_attributes_only)&(!is.null(indices_of_subset))){
            gauge_ids = gauge_ids[indices_of_subset]
            lon = lon[indices_of_subset]
            lat = lat[indices_of_subset]
        }

    }
    nc_close(fid)

    if(all_flow_variables){
        flow_time_series = array(NA, dim=c(dim(stages), 3))
        flow_time_series[,,1] = stages
        flow_time_series[,,2] = uhs
        flow_time_series[,,3] = vhs
    }else{
        flow_time_series = stages
    }

    output = list(attr = run_atts, flow_time_series = flow_time_series, gauge_ids = gauge_ids, 
        indices_of_subset=indices_of_subset, lon=lon, lat=lat, elev=elev)
    return(output)
}

#' Combine tsunami unit sources into tsunami events
#'
#' This function combines data describing earthquake events with data describing
#' unit source geometries, and files containing flow time-series for each 
#' unit source. It can be used to produce flow time-series for earthquake events
#' (assuming linearity), or derive summary statistics from them. The user
#' provides the function to read the flow time-series (this will vary depending
#' on the tsunami propagation solver used). 
#' 
#' @param earthquake_events data.frame with earthquake events, e.g. from the 
#' output of \code{get_all_earthquake_events}
#' @param unit_source_statistics data.frame with unit source summary stats, e.g.
#' from the output of \code{discretized_source_summary_statistics}. It must
#' have a column named 'event_index_string' giving the unit-source indices in the
#' event, and a column 'slip' giving the earthquake slip.
#' @param unit_source_flow_files vector of filenames, corresponding to
#' rows of unit_source_statistics, containing flow time-series for each unit
#' source
#' @param get_flow_time_series_function function to read the flow_time_series
#' data. This function is provided by the user, and is expected to vary depending
#' on which flow solver is used. The function must take as input a single
#' unit_source_flow_file, and an optional indices_of_subset vector which
#' contains the indices of flow_time_series to extract, or NULL to extract all
#' indices. This function must returns a list containing an element named
#' "flow_time_series", which is EITHER a matrix flow_time_series[i,j] containing stage
#' time-series, with i indexing the gauge, and j the time stage time slice, OR
#' a three dimensional array including variables other than just stage, such as uh, vh. (e.g.
#' flow_time_series[i,j,k] where i indexes the station, j the time, and k the
#' variable, typically k=1 is stage, k=2 is uh, and k=3 is vh). The list that
#' the function returns can also contain entries with other names, but they
#' are ignored by this function
#' @param indices_of_subset If not null, the value of indices_of_subset that is
#' passed to get_flow_time_series_function
#' @param verbose logical. If TRUE, print information on progress
#' @param summary_function function which takes the flow data for a single 
#' earthquake event as input, and returns 'anything you like' as output. This is applied 
#' to the flow data for each event before it is output. If NULL, the full flow
#' time-series is provided. This function could be used to compute e.g.
#' the maxima and period of the stage time-series at each gauge, while avoiding
#' having to store the full waveforms for all events in memory.
#' @export
#'
make_tsunami_event_from_unit_sources<-function(
    earthquake_events, 
    unit_source_statistics, 
    unit_source_flow_files,
    get_flow_time_series_function = get_flow_time_series_SWALS,  
    indices_of_subset=NULL, 
    verbose=FALSE,
    summary_function=NULL){

    if(all(c('slip', 'event_slip_string') %in% names(earthquake_events))){
        msg = paste0('earthquake_events cannot have both a column named "slip" ', 
            'and a column named "event_slip_string", since the presence of ', 
            'one or the other is used to distinguish stochastic slip from uniform slip')
        stop(msg)
    }

    if(verbose) print('Finding which unit sources we need ...')

    num_eq = length(earthquake_events[,1])
    events_data = vector(mode='list', length=num_eq)

    # Figure out which unit sources we need flow_time_series for 
    required_unit_sources = vector(mode='list', length=num_eq)
    for(i in 1:num_eq){
        required_unit_sources[[i]] = 
            get_unit_source_indices_in_event(earthquake_events[i,])
    }

    union_required_unit_sources = unique(unlist(required_unit_sources))

    # Double check that the unit_source_statistics are correctly numbered, and
    # ordered
    stopifnot(all(unit_source_statistics$subfault_number == 
        1:length(unit_source_statistics$subfault_number)))

    if(verbose) print('Reading required unit sources ...')

    # Read all the unit source tsunami data that we require
    # We make a list that is long enough to hold all unit source tsunami
    # results , but only read in the ones that we need.
    flow_data = vector(mode='list', 
        length=length(unit_source_flow_files))
    for(i in union_required_unit_sources){

        netcdf_file = unit_source_flow_files[i]

        flow_data[[i]] = get_flow_time_series_function(
            netcdf_file, 
            indices_of_subset = indices_of_subset)

        names(flow_data)[i] = netcdf_file

        gc()
    }
  
    if(verbose) print('Summing unit sources ...') 

    # Make a matrix in which we sum the flow_time_series for each event
    first_uss = which(!is.na(names(flow_data)))[1]
    template_flow_data = flow_data[[first_uss]]$flow_time_series * 0

    if('slip' %in% names(earthquake_events)){
        uniform_slip = TRUE
    }else{
        if(!('event_slip_string' %in% names(earthquake_events))){
            stop('earthquake_events must either have a column named "slip", OR one named "event_slip_string"')
        }
        uniform_slip = FALSE
    }

    # Do the sum
    for(i in 1:num_eq){
        if(verbose) print(paste0('    event ', i))
        earthquake_event = earthquake_events[i,]
        event_unit_sources = required_unit_sources[[i]]

        template_flow_data = template_flow_data * 0

        if(uniform_slip){
            # Sum the unit sources [each with 1m slip]
            for(j in event_unit_sources){
                template_flow_data = template_flow_data + 
                    flow_data[[j]]$flow_time_series
            }

            if(is.null(summary_function)){
                # Rescale the slip value -- uniform slip!
                events_data[[i]] = template_flow_data * earthquake_event$slip   
            }else{
                template_flow_data = template_flow_data * earthquake_event$slip
                events_data[[i]] = summary_function(template_flow_data)
            }
        }else{
            # Stochastic slip case

            # read the slip vector in it's funny character format.
            slip_vector = scan(text=gsub('_', ' ', earthquake_event$event_slip_string), quiet=TRUE)
            stopifnot(length(slip_vector) == length(event_unit_sources))

            # Sum the non-uniform slip
            for(j in 1:length(event_unit_sources)){
                template_flow_data = template_flow_data +
                    flow_data[[event_unit_sources[j]]]$flow_time_series * slip_vector[j]
            }

            if(is.null(summary_function)){
                # Rescale the slip value -- uniform slip!
                events_data[[i]] = template_flow_data 
            }else{
                events_data[[i]] = summary_function(template_flow_data)
            }
        }
    }
    rm(flow_data, template_flow_data)
    gc()

    return(events_data)
}