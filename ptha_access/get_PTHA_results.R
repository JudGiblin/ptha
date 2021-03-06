#
# Codes to remotely access various datasets from new Australian PTHA, on the NCI
#

suppressPackageStartupMessages(library(raster))
if(!exists('config_env')){
    config_env = new.env()
    source('R/config.R', local=config_env)
}
get_supporting_data = new.env()
source('R/get_supporting_data.R', local=get_supporting_data)
source('R/sum_tsunami_unit_sources.R', local=TRUE)
 

#' Read key summary statistics for earthquake events on the source-zone
#'
#' The code reads the files from the web, so an internet connection is required.
#' At the moment no caching of data is implemented. Also, the file sizes range
#' greatly (from a few MB up to 15GB). Subsetting must be used on the large files
#' (assuming typical 2018 internet speeds).
#'
#' @param source_zone Name of source_zone
#' @return list with 'events' giving summary statistics for the earthquake
#' events, and 'unit_source_statistics' giving summary statistics for each
#' unit source
#' @export
#' @examples
#' puysegur_data = get_source_zone_events_data('puysegur')
#'
get_source_zone_events_data<-function(source_zone=NULL, slip_type='stochastic', desired_event_rows = NULL){

    err = FALSE
    if(is.null(source_zone)){
        err = TRUE
    }else{
        if(sum(config_env$source_names_all == source_zone) == 0) err=TRUE
    }

    if(err){
        print('You did not pass a valid source_zone to get_source_zone_events_data. The allowed source_zone values are:')
        print(paste0('   ', config_env$source_names_all))
        print('Please pass one of the above source_zone names to this function to get its metadata')
        # Fail gracefully
        output = list(events = NA, unit_source_statistics=NA, gauge_netcdf_files=NA)
        return(invisible(output))
    }

    stopifnot(slip_type %in% c('uniform', 'stochastic', 'variable_uniform'))

    #
    # Get the earthquake events data
    #
    nc_web_addr = paste0(config_env$.GDATA_OPENDAP_BASE_LOCATION, 
        'SOURCE_ZONES/', source_zone, '/TSUNAMI_EVENTS/all_', slip_type, 
        '_slip_earthquake_events_', source_zone, '.nc')    

    events_data = read_table_from_netcdf(nc_web_addr, desired_rows = desired_event_rows)

    #
    # Get the unit source summary statistics
    #
    nc_web_addr = paste0(config_env$.GDATA_OPENDAP_BASE_LOCATION, 'SOURCE_ZONES/', 
        source_zone, '/TSUNAMI_EVENTS/unit_source_statistics_', source_zone, 
        '.nc')    

    unit_source_statistics = read_table_from_netcdf(nc_web_addr)

    gauge_netcdf_files = unit_source_statistics$tide_gauge_file 

    # Append the web address to the files 
    gauge_netcdf_files_reordered = sapply(gauge_netcdf_files, 
        config_env$adjust_path_to_gdata_base_location)

    output = list()
    output[['events']] = events_data
    output[['unit_source_statistics']] = unit_source_statistics
    output[['gauge_netcdf_files']] = gauge_netcdf_files_reordered
    

    return(invisible(output))
}

#' Create initial conditions (i.e. water surface deformation) for tsunami model
#'
#' @param source_zone_events_data output from \code{get_source_zone_events_data}
#' @param event_ID integer ID, corresponding to the row-index of the event in
#' the events table (which is contained in source_zone_events_data) 
#' @param force_file_download logical. If FALSE, we check for files in the local
#' cache and use those if they exist, or download them otherwise. If TRUE, we 
#' download the files to the local cache, irrespective of whether files with
#' the same name already exist.
#' @return A raster with the initial free surface deformation
#' @export
#' @examples
#' puysegur_data = get_source_zone_events_data('puysegur')
#' # Get initial condition corresponding to the event in
#' # puysegur$events[250,]
#' initial_conditions = get_initial_condition_for_event(
#'    puysegur_data, event_ID=250)
#' plot(initial_conditions)
#'
get_initial_condition_for_event<-function(source_zone_events_data, event_ID,
    force_file_download=FALSE){

    # Shorthand notation
    szed = source_zone_events_data

    # Get all raster names
    sz_rasters = szed$unit_source_statistics$initial_condition_file
   
    # Get event specific information 
    event_data = szed$events[event_ID,]
    event_slip = event_data$slip

    if(any(event_data$rate_annual == 0)){
        print('Warning: You requested the initial condition for an event that has an annual rate of zero (i.e. it is treated as impossible for the purposes of the PTHA)!')
    }

    event_raster_indices = scan(
        text=gsub("-", " ", event_data$event_index_string), quiet=TRUE)

    event_rasters = sz_rasters[event_raster_indices]

    # Figure out the raster names on this machine
    event_rasters_base = unlist(lapply(
        as.list(event_rasters), 
        f<-function(x) strsplit(x, split='SOURCE_ZONES')[[1]][2]))
    event_rasters_base = paste0('SOURCE_ZONES', event_rasters_base)

    if(!file.exists(event_rasters_base[1])){
        dir.create(dirname(event_rasters_base[1]), recursive=TRUE, showWarnings=FALSE)
    }

    # Figure out the raster names on NCI
    event_rasters_online = paste0(config_env$.GDATA_HTTP_BASE_LOCATION, 
        event_rasters_base)

    # Loop over all rasters, and if we can't find them in local directories,
    # then download them
    for(i in 1:length(event_rasters_base)){
        local_raster_name = event_rasters_base[i]
        if(force_file_download | (!file.exists(local_raster_name))){
            if(file.exists(event_rasters_online[i])){
                # This can happen if running code from NCI
                file.copy(event_rasters_online[i], local_raster_name)
            }else{
                download.file(event_rasters_online[i], local_raster_name)
            }
        }
    }

    # Read and sum the rasters
    variable_slip = ('event_slip_string' %in% names(event_data))
    if(variable_slip){
        slip = as.numeric(strsplit(event_data$event_slip_string, '_')[[1]])
    }else{
        slip = rep(event_data$slip, length(event_rasters_base))
    }

    r1 = raster(event_rasters_base[1])*0
    for(i in 1:length(event_rasters_base)){
        r1 = r1 + slip[i] * raster(event_rasters_base[i])
    }

    return(r1)
}

#' Download flow time-series from NCI
#'
#' @param source_zone_events_data output from \code{get_source_zone_events_data}
#' @param event_ID The row indices of the earthquake event(s) in source_zone_events_data$events
#' @param hazard_point_ID The numeric ID of the hazard point
#' @param target_polygon A SpatialPolygons object. All gauges inside this are selected
#' @param target_points A matrix of lon/lat point locations. The nearest gauge to each is selected
#' @param target_indices A vector with integer indices corresponding to where the gauge values are stored.
#' @param store_by_gauge Return the flow variables as a list with one gauge per
#' entry. Otherwise, return as a list with one event_ID per entry
#' @return Flow time-series
#'
get_flow_time_series_at_hazard_point<-function(source_zone_events_data, event_ID, 
    hazard_point_ID = NULL, target_polygon = NULL, target_points=NULL, target_indices = NULL,
    store_by_gauge=TRUE){

    is_null_hpID = is.null(hazard_point_ID)
    is_null_target_poly = is.null(target_polygon)
    is_null_target_points = is.null(target_points)
    is_null_target_indices = is.null(target_indices)

    only_one_input = is_null_hpID + is_null_target_poly + is_null_target_points + is_null_target_indices
    if(only_one_input != 3){
        print(only_one_input)
        stop('Only one of hazard_point_ID, target_polygon, target_points, target_indices should provided as non-NULL')
    }


    szed = source_zone_events_data

    if(!any(grepl('rptha', .packages(all=TRUE)))){
        stop('This function requires the rptha package to be installed, but the latter cannot be detected')
    }

    # Case of user-provided point IDs
    if(!is.null(hazard_point_ID)){
        # Find the index of the points matching event_ID inside the netcdf file
        indices_of_subset = get_netcdf_gauge_index_matching_ID(
            szed$gauge_netcdf_files[1],
            hazard_point_ID)

    }

    # Case of user-provided polygon
    if(!is.null(target_polygon)){

        indices_of_subset = get_netcdf_gauge_indices_in_polygon(
            szed$gauge_netcdf_files[1], target_polygon)

    }

    # Case of user-provided point locations
    if(!is.null(target_points)){
        indices_of_subset = get_netcdf_gauge_indices_near_points(
            szed$gauge_netcdf_files[1], target_points)
    }

    if(!is.null(target_indices)){
        indices_of_subset = target_indices
    }

    event_times = get_netcdf_gauge_output_times(szed$gauge_netcdf_files[1])
    gauge_locations = get_netcdf_gauge_locations(szed$gauge_netcdf_files[1], indices_of_subset)

    
    if(any(szed$events$rate_annual[event_ID] == 0)){
        print('Warning: You requested the initial condition for an event that has an annual rate of zero (i.e. it is treated as impossible for the purposes of the PTHA!)')
    }


    flow_var_batch = make_tsunami_event_from_unit_sources(
        szed$events[event_ID,], 
        szed$unit_source_statistics, 
        szed$gauge_netcdf_files,
        indices_of_subset=indices_of_subset, 
        verbose=FALSE,
        summary_function=NULL)

    if(store_by_gauge){
        # Store as a list, with one gauge in each list
        flow_var = vector(mode='list', length=length(indices_of_subset))
        for(i in 1:length(indices_of_subset)){
            flow_var[[i]] = array(0, 
                dim=c(length(event_ID), dim(flow_var_batch[[1]])[2:3]))
            for(j in 1:length(event_ID)){
                flow_var[[i]][j,,] = flow_var_batch[[j]][i,,]
            }
        }

        names(flow_var) = gauge_locations$gaugeID
    }else{
        # Store as a list, with one event in each entry
        names(flow_var_batch) = event_ID
        flow_var = flow_var_batch
    }

    output = list(time=event_times, flow=flow_var, locations=gauge_locations, events=szed$events[event_ID,])

    return(output)
}

#
# Utility function to determine the index of a hazard point in a netcdf file
#
# I often allow the user to pass a gaugeID, or a point, or an index. Then I need
# code to convert that into an index for the given netcdf file, and check that inputs are valid, etc. 
# This function takes care of that.
#
parse_ID_point_index_to_index<-function(netcdf_file, hazard_point_gaugeID, target_point, target_index){

    null_index = is.null(target_index)
    null_point = is.null(target_point)[1]
    null_ID = is.null(hazard_point_gaugeID)[1]

    only_one_input = null_ID + null_point + null_index
    if(only_one_input != 2){
        print(only_one_input)
        stop('Only one of hazard_point_gaugeID, target_point, target_index should provided as non-NULL')
    }

    if(null_index){
        if(!null_point){
            if(length(target_point) != 2){
                stop('Can only provide a single point')
            }
            # Find a site nearest the point
            target_index = get_netcdf_gauge_indices_near_points(
                netcdf_file,
                cbind(target_point[1], target_point[2]))
        }
    
        if(!null_ID){
            if(length(hazard_point_gaugeID) != 1){
                stop('Can only provide a single gauge ID')
            }
            # Find a site matching the ID
            target_index = get_netcdf_gauge_index_matching_ID(
                netcdf_file,
                hazard_point_gaugeID)
        }
    }

    return(target_index)
}

#'
#' Get the stage vs exceedance rate curves at a hazard point
#'
#' @param hazard_point_gaugeID numerical gaugeID of the hazard point of interest
#' @param target_point vector with c(lon, lat) of the target point
#' @param target_index integer index of the hazard point in the file
#' @param source_name Name of source-zone. If NULL, then return the rates for
#'     the sum over all source-zones
#' @param make_plot If TRUE, plot the stage vs return period curve for stochastic slip
#' @param non_stochastic_slip_sources If TRUE, also return curves for uniform
#'     and variable_uniform slip events
#' @return list containing return period info for the source-zone
#'
get_stage_exceedance_rate_curve_at_hazard_point<-function(
    hazard_point_gaugeID = NULL, 
    target_point =NULL, 
    target_index = NULL,
    source_name = NULL,
    make_plot = FALSE,
    non_stochastic_slip_sources=FALSE,
    only_mean_rate_curve=FALSE){

    if(is.null(source_name)){
        source_name = 'sum_over_all_source_zones'
        stage_exceedance_rate_curves_file = paste0(config_env$.GDATA_OPENDAP_BASE_LOCATION,
            'EVENT_RATES/tsunami_stage_exceedance_rates_', source_name, '.nc')
    }else{
        stage_exceedance_rate_curves_file = paste0(config_env$.GDATA_OPENDAP_BASE_LOCATION,
            'SOURCE_ZONES/', source_name, '/TSUNAMI_EVENTS/tsunami_stage_exceedance_rates_', 
            source_name, '.nc')
    }

    # Parse the input arguments into a target index
    target_index = parse_ID_point_index_to_index(
        stage_exceedance_rate_curves_file, hazard_point_gaugeID, 
        target_point, target_index)

    fid = nc_open(stage_exceedance_rate_curves_file, readunlim=FALSE)

    output = list()
    output$stage = fid$dim$stage$vals 

    vars = 'stochastic_slip_rate'
    if(non_stochastic_slip_sources){
        vars = c(vars, 'uniform_slip_rate', 'variable_uniform_slip_rate')
    }
    if(!only_mean_rate_curve){
        vars = c(vars, paste0(vars,'_upper_ci'), paste0(vars, '_lower_ci'), 
            paste0(vars, '_median'), paste0(vars, '_16pc'), paste0(vars, '_84pc'))
    }
    # Add in the variable_mu
    vars = c(vars, paste0('variable_mu_', vars))

    # Read the file
    for(i in 1:length(vars)){
        output[[vars[i]]] = ncvar_get(fid, vars[i],  start=c(1, target_index), count=c(-1,1))
    }

    if(!only_mean_rate_curve){
        output$lon = ncvar_get(fid, 'lon', start=target_index, count=1)
        output$lat = ncvar_get(fid, 'lat', start=target_index, count=1)
        output$elev = ncvar_get(fid, 'elev', start=target_index, count=1)
        output$gaugeID = ncvar_get(fid, 'gaugeID', start=target_index, count=1)
    }
    output$target_index = target_index
    output$source_name = source_name
    output$stage_exceedance_rate_curves_file = stage_exceedance_rate_curves_file

    nc_close(fid)
    
    if(make_plot){
        title = paste0('Tsunami max-stage exceedance rates (stochastic slip, ', source_name, ')\n',
            'site = (', round(output$lon,3), ',', round(output$lat, 3), '); depth = ', 
            round(output$elev, 1), ' m; ID = ', round(output$gaugeID,3)) 
        options(scipen=5)
        plot(output$stage, output$stochastic_slip_rate, log='xy',
            xlim=c(0.02, 20), ylim=c(1.0e-04, 1), t='o', col='red', pch=19, cex=0.3,
            xlab='Maximum tsunami waterlevel above MSL', 
            ylab = 'Exceedance Rate (events/year)',
            main = title)
        points(output$stage, output$stochastic_slip_rate_upper, t='l', col='red')
        points(output$stage, output$stochastic_slip_rate_lower, t='l', col='red')
        points(output$stage, output$stochastic_slip_rate_median,t='l', col='red')
        points(output$stage, output$stochastic_slip_rate_16pc,  t='l', col='red')
        points(output$stage, output$stochastic_slip_rate_84pc,  t='l', col='red')

        points(output$stage, output$variable_mu_stochastic_slip_rate,       t='o', col='purple', cex=0.3, pch=19)
        points(output$stage, output$variable_mu_stochastic_slip_rate_upper, t='l', col='purple')
        points(output$stage, output$variable_mu_stochastic_slip_rate_lower, t='l', col='purple')
        points(output$stage, output$variable_mu_stochastic_slip_rate_median,t='l', col='purple')
        points(output$stage, output$variable_mu_stochastic_slip_rate_16pc,  t='l', col='purple')
        points(output$stage, output$variable_mu_stochastic_slip_rate_84pc,  t='l', col='purple')

        abline(v=c(0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20), col='orange', lty='dotted')
        abline(h=10**(seq(-6,0)), col='orange', lty='dotted')
        legend('topright', 
            c('Mean estimated rate', '2.5, 16, 50, 84, 97.5 % Percentiles', 
              'Mean estimated rate (variable mu)', '2.5, 16, 50, 84, 97.5 % Percentiles (variable mu)'
            ), 
            col=c('red', 'red', 'purple', 'purple'), 
            lty=c('solid', 'solid', 'solid', 'solid'), pch=c(19, NA, 19, NA), 
            pt.cex=c(0.3, NA, 0.3, NA), bg='white')
    }
    return(output)
}

#' Get stage vs exceedance rate curve for EVERY source-zone
#'
#' We loop over 'get_stage_exceedance_rate_curve_at_hazard_point'
#'
#' @param hazard_point_gaugeID numerical gaugeID of the hazard point of interest
#' @param target_point vector with c(lon, lat) of the target point
#' @param target_index integer index of the hazard point in the file
#' @param non_stochastic_slip_sources If TRUE, also get uniform and variable uniform rate curves
#' @param only_mean_rate_curve If TRUE, do not get credible interval rate curves
#' @return List of lists with the return period info for each source-zone
#'
get_stage_exceedance_rate_curves_all_sources<-function(
    hazard_point_gaugeID = NULL, 
    target_point = NULL, 
    target_index = NULL,
    non_stochastic_slip_sources=FALSE,
    only_mean_rate_curve=FALSE){

    all_sources = config_env$source_names_all

    outputs = vector(mode='list', length=length(all_sources))

    for(i in 1:length(all_sources)){

        if(i == 1){
            # On the first pass, we might not pass target_index
            outputs[[i]] = get_stage_exceedance_rate_curve_at_hazard_point(
                hazard_point_gaugeID,
                target_point,
                target_index, 
                source_name = all_sources[i],
                non_stochastic_slip_sources = non_stochastic_slip_sources,
                only_mean_rate_curve=only_mean_rate_curve)
        }else{
            # On the second pass, we can pass target_index, which is faster
            outputs[[i]] = get_stage_exceedance_rate_curve_at_hazard_point(
                target_index = outputs[[1]]$target_index, 
                source_name = all_sources[i],
                non_stochastic_slip_sources = non_stochastic_slip_sources,
                only_mean_rate_curve=only_mean_rate_curve)
        }
        names(outputs)[i] = all_sources[i]

    }
    return(outputs)
}

#'
#' For a point, get a list which contains (for each source-zone),
#' Mw, max_stage, event_rate. Combined with a 'desired' max stage,
#' this can be used to select events for further study.
#'
#' @param hazard_point_gaugeID numerical gaugeID of the hazard point of interest
#' @param target_point vector with c(lon, lat) of the target point
#' @param target_index integer index of the hazard point in the file
#' @param all_source_names vector with the source names to extract data from
#' @return list (one entry for each source) containing a list with 
#'   peak_stage, Mw, event_rate
#'
get_peak_stage_at_point_for_each_event<-function(hazard_point_gaugeID = NULL, 
    target_point=NULL, target_index = NULL, all_source_names = NULL,
    slip_type = 'stochastic'){


    stage_exceedance_rate_curves_file = paste0(config_env$.GDATA_OPENDAP_BASE_LOCATION,
        'EVENT_RATES/tsunami_stage_exceedance_rates_sum_over_all_source_zones.nc')
    # Parse the input arguments into a target index
    target_index = parse_ID_point_index_to_index(
        stage_exceedance_rate_curves_file, hazard_point_gaugeID, 
        target_point, target_index)

    if(is.null(all_source_names)){
        all_source_names = basename(dirname(Sys.glob('SOURCE_ZONES/*/EQ_SOURCE')))
    }

    if(slip_type == 'stochastic'){
        file_base = 'all_stochastic_slip_earthquake_events_'
    }else if(slip_type == 'variable_uniform'){
        file_base = 'all_variable_uniform_slip_earthquake_events_'
    }else if(slip_type == 'uniform'){
        file_base = 'all_uniform_slip_earthquake_events_'
    }else{
        stop('unrecognized slip_type')
    }

    output = vector(mode='list', length=length(all_source_names))
    names(output) = all_source_names

    # Download the data for all sourcezones
    for(i in 1:length(all_source_names)){
    
        nm = all_source_names[i]
        print(nm)
        try_again = TRUE

        # Allow for the download to fail up to 'max_tries' times
        counter = 0
        max_tries = 20
        has_vars = c(FALSE, FALSE)
        while(try_again){

            counter = counter + 1

            # Read the max stage
            if(!has_vars[1]){
                nc_file1 = paste0(config_env$.GDATA_OPENDAP_BASE_LOCATION, 'SOURCE_ZONES/',
                    nm, '/TSUNAMI_EVENTS/', file_base, 'tsunami_', 
                    nm, '.nc')
                fid1 = nc_open(nc_file1, readunlim=FALSE, suppress_dimvals=TRUE)
                local_max_stage = try(ncvar_get(fid1, 'max_stage', start=c(1,target_index), 
                    count=c(fid1$dim$event$len,1)))

                ## I'm commenting out local_period, since the zero-crossing period
                ## is quite effected by small oscillations in the stage, and not so useful
                ## for qualitative interpretation
                #local_period = try(ncvar_get(fid1, 'period', start=c(1,target_index), 
                #    count=c(fid1$dim$event$len,1)))
                nc_close(fid1)
                #if((class(local_max_stage) != 'try-error') & (class(local_period) != 'try-error')) has_vars[1] = TRUE
                if((class(local_max_stage) != 'try-error')) has_vars[1] = TRUE
            }

            # Read Mw and the event rate from the file that doesn't contain the tsunami
            # max-stage, because the read access is faster
            if(!has_vars[2]){
                nc_file2 = paste0(config_env$.GDATA_OPENDAP_BASE_LOCATION, 'SOURCE_ZONES/',
                    nm, '/TSUNAMI_EVENTS/', file_base, 
                    nm, '.nc')
                fid2 = nc_open(nc_file2, readunlim=FALSE, suppress_dimvals=TRUE)
                local_Mw = try(ncvar_get(fid2, 'Mw'))
                local_rate = try(ncvar_get(fid2, 'rate_annual'))
                local_Mw_variable_mu = try(ncvar_get(fid2, 'variable_mu_Mw'))
                local_rate_variable_mu = try(ncvar_get(fid2, 'variable_mu_rate_annual'))
                nc_close(fid2)
                if((class(local_Mw) != 'try-error') & 
                   (class(local_rate) != 'try-error') &
                   (class(local_rate_variable_mu) != 'try-error') &
                   (class(local_Mw_variable_mu) != 'try-error')
                    ) has_vars[2] = TRUE
            }

            output[[i]] = list(
                Mw = local_Mw,
                max_stage = local_max_stage,
                #period = local_period,
                scenario_rate_is_positive = (local_rate>0),
                target_index=target_index,
                slip_type=slip_type,
                variable_mu_Mw = local_Mw_variable_mu,
                variable_mu_scenario_rate_is_positive = (local_rate_variable_mu>0)
                )

            # Error handling
            if(!all(has_vars == TRUE)){

                if(counter <= max_tries){
                    try_again = TRUE
                    print('remote read failed, trying again')
                }

                if(counter > max_tries){
                    try_again = FALSE
                    print('remote read failed too many times, skipping')
                }
            }else{
                try_again = FALSE
            }
        }
    }

    return(output)
}

#'
#' Function to summarize event properties. This MAY help
#' in choosing one or a few scenarios from a set of scenarios. 
#'
summarise_events<-function(events_near_desired_stage){

    # shorthand
    ends = events_near_desired_stage
   
    mws = ends$events$Mw
    rates = ends$events$rate_annual
    peak_slip = sapply(ends$events$event_slip_string, 
        f<-function(x) max(as.numeric(strsplit(x, '_')[[1]])),
        USE.NAMES=FALSE)
    mean_slip = sapply(ends$events$event_slip_string, 
        f<-function(x) mean(as.numeric(strsplit(x, '_')[[1]])),
        USE.NAMES=FALSE)
    nsources = sapply(ends$events$event_slip_string, 
        f<-function(x) length(as.numeric(strsplit(x, '_')[[1]])),
        USE.NAMES=FALSE)
    peak_slip_alongstrike = ends$events$peak_slip_alongstrike_ind 

    magnitude_prop_le = sapply(mws, f<-function(x) sum(rates * (mws <= x)))/sum(rates)
    magnitude_prop_lt = sapply(mws, f<-function(x) sum(rates * (mws < x)))/sum(rates)

    magnitude_prop_mid = 0.5*(magnitude_prop_le + magnitude_prop_lt)

    # Reproducible jitter
    if(exists('.Random.seed')){
        oldseed = .Random.seed
    }else{
        p = runif(1) # Now we will have a random seed
        oldseed = .Random.seed
    }
    set.seed(1)
 
    obs = cbind(jitter(magnitude_prop_mid, 0.0001), peak_slip, mean_slip, nsources, peak_slip_alongstrike)
    if(nrow(obs) > 1){
        # We can do a mahalanobis distance calculation
        obs = apply(obs, 2, f<-function(x) qnorm(rank(x)/(length(x)+1)))
        mh_distance = try(mahalanobis(obs, center=mean(obs), cov=cov(obs)), silent=TRUE)
        if(class(mh_distance) == 'try-error'){
            # Mahalanobis distance failed (perhaps too few events, or
            # problematic input data leading to singular covariance matrix).
            # Prioritize events with intermediate magnitudes
            mh_distance = abs(magnitude_prop_mid - 0.5) 
        }
    }else{
        mh_distance = 0
    }

    # Undo reproducible random jitter
    .Random.seed <<- oldseed

    return(data.frame(mws, peak_slip, mean_slip, nsources, peak_slip_alongstrike, 
        magnitude_prop_mid, mh_distance))
}

