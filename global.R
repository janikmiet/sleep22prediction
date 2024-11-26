library(dplyr)
# library(tidyverse)
library(tidyr)
library(arrow)
library(ggplot2)

# PREDICTION: Creates osasimulation
create_osapred <- function(locations=c("Albania","Armenia","Austria","Azerbaijan","Belarus","Belgium","Bosnia and Herzegovina","Bulgaria","Croatia","Cyprus","Denmark","Estonia","Finland","France","Georgia","Germany","Greece","Hungary","Iceland","Ireland","Italy","Kazakhstan","Latvia","Lithuania","Luxembourg","Malta","Montenegro","Netherlands","Norway","Poland","Portugal","Romania","Serbia","Slovakia","Slovenia","Spain","Sweden","Switzerland","Turkey","Ukraine","United Kingdom" ), 
                           prevalence_start = NA,
                           prevalence_limit = 0.80,
                           # incidence_avg="1yr",
                           incidence_male = NA, ## TODO new
                           incidence_female = NA, ## TODO new
                           years=c(2020,2035),
                           intervention=FALSE,
                           data_output = "data/",
                           WRITE_DATA = FALSE,
                           WRITE_NAME=""){
  
  # OSAPOP PREVELENCE CALCULATOR
  # Creates prevalence.parquet file to output folder
  # - Population info per sex & age
  # - Sleep apnea patients per country
  # - Costs
  
  ##  CHECK INPUTS
  locations <- match.arg(locations, several.ok = TRUE) # locations list of avaibility
  stopifnot((prevalence_start < prevalence_limit) | is.na(prevalence_start)) # prevalence_start > 0.001 and < 1
  stopifnot(prevalence_limit <= 1 & prevalence_limit >= 0.01) # prevalence_limit between prevalence_start and 1 
  stopifnot(years[1] >= 2020 & years[2] <= 2035)# years between 2020 and 2100
  # stopifnot((incidence_male >= 0 & incidence_male <= 0) | is.na(incidence_male))
  # stopifnot((incidence_female >= 0 & incidence_female <= 0) | is.na(incidence_female))
  # stopifnot(is.logical(intervention)) # intervention TRUE and FALSE / TODO
  
  
  ver = "1.50"
  library(tidyverse)
  library(dplyr)
  library(ggplot2)
  library(arrow)
  options(scipen = 999)
  options(dplyr.summarise.inform = FALSE)
  
  # INPUTS:
  # cntry = "Finland"
  # data_output = "data/prev04/"
  # years = c(2020, 2035)
  # prevalence_start = NA
  # prevalence_limit = 0.80
  # incidence_male = 0.0210
  # incidence_female = 0.0170
  # intervention=FALSE
  # WRITE_DATA =FALSE
  
  print(paste0(Sys.time(), " - Sleep Apnea Prediction Function ", ver))
  
  # OPEN ALL DATAS ----
  if(TRUE){
    pop_full <- read_parquet(paste0("data/populations.parquet")) ## Populaatio ennusteet 2020-
    osa_benjafield_full <- read_parquet("data/osa_benjafield.parquet") %>% 
      mutate(prev = `Moderate-Severe`) ## Aloitusprevalenssi vakiot
    deat_rate_full <- read_parquet("data/WHO_drates.parquet") ## Death rate
    cost_osa <- read_parquet("data/cost_osa.parquet")
    ## Ratiot
    ratio_pop_agegroup_to_age <- read_parquet("data/ratio_pop_agegroup_to_age.parquet") ### Populaatio painokertoimen
    ratio_prev_total_to_age <- read_parquet("data/ratio_prev_total_to_age.parquet") ## TODO tarkista kaytetaanko?
    ratio_prev_to_wide <- read_parquet("data/ratio_prev_to_wide.parquet") ## insidenssi ratiot
    ratio_inc_to_1v2v <- read_parquet("data/ratio_inc_to_1v2v.parquet") ## insidenssi ratiot 1v 2v # TODO UUUS RATIO
    ratio_incidence_avg <- read_parquet("data/ratio_incidence_avg.parquet") %>% 
      filter(avg == "1yr") 
  }
  
  
  fulldata <- tibble()
  for (cntry in locations) {
    print(paste0(Sys.time(), " ", toupper(cntry), " Sleep Apnea Prediction for ", years[1], " to ", years[2]))
    # BASE YEAR CALCULATION -----
    if(TRUE){
      ## VAIHE 1 baseyear pop and osapop ----
      # Otetaan maan populaatio ja lasketaan vuodelle 2020 asetetun prevalenssin mukaiset OSA tapaukset
      pop <- pop_full %>% 
        filter(location_name == cntry) %>% 
        filter(year_id == years[1])
      
      # VAIHE 2 Muutetaan aineisto 1v tasolle -----
      ratios <- ratio_pop_agegroup_to_age %>% 
        # left_join(ratio_prev_agegroup_to_age, by = c("sex", "age", "age_group_name")) %>% 
        left_join(ratio_prev_total_to_age, by = c("sex", "age", "age_group_name"))
      
      ## Alkuprevalenssin määritys
      if(is.na(prevalence_start)){
        ## Valitaan benjafieldin prevalenssi
        osa_benjafield <- osa_benjafield_full %>% 
          filter(location_name == cntry) %>% 
          select(location_name, prev)
        ## Lasketaan populaatio per ika ja prevalenssi n per ika kayttaen maariteltya prevalenssia
        pop <- pop %>% 
          left_join(ratios, by = c("sex", "age_group_name")) %>% 
          mutate(
            pop_age = total_population * age_group_ratio,
            n_prev2 = sum(pop$total_population) * osa_benjafield$prev * ratio_prev_age 
          )
      }else{
        ## Lasketaan populaatio per ika ja prevalenssi n per ika kayttaen maariteltya prevalenssia
        pop <- pop %>% 
          left_join(ratios, by = c("sex", "age_group_name")) %>% 
          mutate(
            pop_age = total_population * age_group_ratio,
            n_prev2 = sum(pop$total_population) * prevalence_start * ratio_prev_age 
          )
      }
      
      ## TARKISTUS:
      # sum(pop$n_prev2, na.rm = T) # spain: 6 053 556, Portugal: 1 084 910
      
      ### VAIHE 3 Insidenssin kertoimien painotus valinnan mukaan ------
      if(TRUE){
        ## FOR TESTING
        # incidence_male = 0.02
        # incidence_female = 0.02
        # Lasketaan kokonaisinsidenssi
        total_incidence <- pop %>% 
          left_join(ratio_incidence_avg) %>% 
          mutate(
            n_incidence = round(pop_age * incidence_age, 0)) %>% 
          group_by(sex) %>% 
          summarise(
            n_incidence = sum(n_incidence, na.rm = T),
            pop = sum(pop_age, na.rm = T)) %>% 
          mutate(
            incidence = round(n_incidence / pop, 3)
          ) %>% 
          select(sex, incidence)
        ## Määritellään kerroin
        ifelse(is.na(incidence_male) | incidence_male == total_incidence$incidence[total_incidence$sex == "male"], 
               incidence_male_multiplier <- 1 , 
               incidence_male_multiplier <-  incidence_male / total_incidence$incidence[total_incidence$sex == "male"])
        ifelse(is.na(incidence_female) | incidence_female == total_incidence$incidence[total_incidence$sex == "female"], 
               incidence_female_multiplier <-  1 , 
               incidence_female_multiplier <- incidence_female / total_incidence$incidence[total_incidence$sex == "female"] )
        ## Muutetaan ratiot
        ratio_incidence_avg <- ratio_incidence_avg %>% 
          mutate(
            multiplier = ifelse(sex == "male", incidence_male_multiplier, incidence_female_multiplier),
            incidence_age = incidence_age * multiplier
          ) %>%
          select(sex, age, incidence_age)
        # ## Tarkistus
        # pop %>%
        #   left_join(ratio_incidence_avg) %>%
        #   mutate(
        #     n_incidence = round(pop_age * incidence_age, 0)) %>%
        #   group_by(sex) %>%
        #   summarise(
        #     n_incidence = sum(n_incidence, na.rm = T),
        #     pop = sum(pop_age, na.rm = T)) %>%
        #   mutate(
        #     incidence = round(n_incidence / pop, 3)
        #   ) %>%
        #   select(sex, incidence)
      }
      
      # VAIHE 4 insidenssi ja muut osuudet -----
      ## Laske kokonaisprevalenssi frekvenssistä aliryhmien määrät
      pop <- pop %>% 
        left_join(ratio_incidence_avg %>% 
                    select(sex,age,incidence_age), 
                  by = join_by(sex, age)) %>% 
        left_join(ratio_inc_to_1v2v, by = join_by(sex, age)) %>% 
        mutate(
          n_osa_0v = round(pop_age * incidence_age, 0), ## Ekalle vuodelle konservatiivinen insidenssi
          n_osa_1v = round(n_osa_0v * year1_ratio, 0), ## Rekisteriaineiston ratio jolla insidenssi 1v tapauksiksi
          n_osa_2v = round(n_osa_0v * year2_ratio, 0), ## Rekisteriaineiston ratio jolla insidenssi 2v tapauksiksi
          n_osa_99v = round(n_prev2 - n_osa_0v - n_osa_1v - n_osa_2v, 0) ## Saadaan kokonaisprevalenssi suureksi
        )
      ## TARKISTUS KOKONAISPREVALENSSI
      # sum(pop$n_osa_0v + pop$n_osa_1v + pop$n_osa_2v + pop$n_osa_3v, na.rm = T)
      # spain: 6053552
    }
    ### BASELINE DATA READY!
    
    
    # SIMULATION 2021 - 2035 ------
    
    ### DATA DEFINITIONS -----
    if(TRUE){
      ## Death rate and max prevalence
      if(!cntry %in% c("Turkey", "United Kingdom")) deat_rate <- deat_rate_full %>% filter(location_name == cntry)
      if(cntry == "Turkey") deat_rate <- deat_rate_full %>% filter(location_name == "Montenegro")
      if(cntry == "United Kingdom") deat_rate <- deat_rate_full %>% filter(location_name == "Ireland")
      deat_rate <- deat_rate[!duplicated(deat_rate),]
      limit_max_prevalence = prevalence_limit ##  Limit max prevalence cases (in last dg year)
    }
    
    ## SIMULATION FOR-LOOP ----
    final <- tibble()
    years_prediction <- seq(years[1] + 1, years[2])
    pb = txtProgressBar(min = 0, max = length(years_prediction), initial = 0)
    for(year in years_prediction){
      setTxtProgressBar(pb, year - years_prediction[1])
      # year = 2021
      # print(year)
      #### Move cases to next year -----
      if(year == years_prediction[1]){
        pop_last <- pop %>% 
          select(location_name, year_id, sex, age_group_name, age, pop_age, n_osa_0v, n_osa_1v, n_osa_2v, n_osa_99v) %>% 
          mutate(
            n_osa_99v = n_osa_2v + n_osa_99v,
            n_osa_2v = n_osa_1v,
            n_osa_1v = n_osa_0v, 
            n_osa_0v = 0
          )
      }else{
        pop_last <- final %>% 
          filter(year_id ==  year - 1) %>% 
          mutate(
            n_osa_99v = n_osa_2v + n_osa_99v,
            n_osa_2v = n_osa_1v,
            n_osa_1v = n_osa_0v, 
            n_osa_0v = 0
          )
      }
      ## age+1 and age_group_name adjust
      pop_last <- pop_last %>% 
        filter(age < 101) %>% 
        mutate(
          age = ifelse(age > 100, 101, age + 1), ## ikä menee yli 100 - pysyy 100v
          age_group_name = case_when(
            age > 89 & age < 95 ~ "90 to 94",
            age > 84 & age < 90 ~ "85 to 89",
            age > 79 & age < 85 ~ "80 to 84",
            age > 74 & age < 80 ~ "75 to 79",
            age > 69 & age < 75 ~ "70 to 74",
            age > 64 & age < 70 ~ "65 to 69",
            age > 59 & age < 65 ~ "60 to 64",
            age > 54 & age < 60 ~ "55 to 59",
            age > 49 & age < 55 ~ "50 to 54",
            age > 44 & age < 50 ~ "45 to 49",
            age > 39 & age < 45 ~ "40 to 44",
            age > 34 & age < 40 ~ "35 to 39",
            age > 29 & age < 35 ~ "30 to 34",
            age > 24 & age < 30 ~ "25 to 29",
            age > 19 & age < 25 ~ "20 to 24",
            age < 20 ~ "under 20",
            age > 94 ~ "95 plus"
          )
        )
      # max(pop_last$age)
      
      ## Reduce cases by death rate -----
      ## Death rate on ikäryhmittäin. Joten oletetaan että 1v iällä on sama rate kuin vastaavalla ikäryhmällä.
      pop_last <- pop_last %>% 
        left_join(deat_rate, by = c("sex", "age_group_name")) %>% 
        mutate(
          n_osa_1v_new = round(n_osa_1v * (1 - death_rate), 0),
          n_osa_2v_new = round(n_osa_2v * (1 - death_rate), 0),
          n_osa_99v_new = round(n_osa_99v * (1 - death_rate), 0)
        )
      
      ### Next year population -----
      pop_next <- pop_full %>% 
        filter(location_name == cntry) %>% 
        filter(year_id == year)
      ## Muutetaan aineisto  1v tasolle
      pop_next <- pop_next %>% 
        left_join(ratio_pop_agegroup_to_age, by = c("sex", "age_group_name")) %>% 
        mutate(
          pop_age = total_population * age_group_ratio)
      
      ## Add insidence -----
      pop_next <- pop_next %>% 
        left_join(ratio_incidence_avg %>% 
                    select(sex,age,incidence_age), 
                  by = join_by(sex, age)) %>% ## TODO uusi
        mutate(
          n_osa_0v_new = round(pop_age * incidence_age, 0)
        )
      
      ## Bind new and old rows -----
      pop_next <- pop_next %>% 
        rename(n_osa_0v = n_osa_0v_new) %>% 
        select(location_name, year_id, sex, age_group_name, age, pop_age, n_osa_0v)
      pop_last <- pop_last %>% 
        select(location_name.x, sex, age_group_name, age, n_osa_1v_new, n_osa_2v_new, n_osa_99v_new) %>% 
        rename(location_name = location_name.x,
               n_osa_1v = n_osa_1v_new,
               n_osa_2v = n_osa_2v_new,
               n_osa_99v = n_osa_99v_new) %>% 
        select(location_name, sex, age_group_name, age, n_osa_1v, n_osa_2v, n_osa_99v)
      ## Simuloidun vuoden tapaukset, yhdistys
      pop_new <- pop_next %>%
        left_join(pop_last, by = c("sex", "age")) %>%
        rename(age_group_name = age_group_name.x,
               location_name = location_name.x) %>%
        mutate(
          ## limit prevalence on last dg year cases
          n_osa_99v = ifelse(
            (pop_age * limit_max_prevalence) >= (n_osa_0v + n_osa_1v + n_osa_2v + n_osa_99v), 
            n_osa_99v,  
            # pop_age * limit_max_prevalence
            pop_age * limit_max_prevalence - (n_osa_0v + n_osa_1v + n_osa_2v) 
          ) 
        ) %>% 
        select(location_name, year_id, sex, age_group_name, age, pop_age, n_osa_0v, n_osa_1v, n_osa_2v, n_osa_99v)
      
      
      ## Final data  ----
      if(year == years_prediction[1]){
        pop_filt <- pop %>% 
          select(location_name, year_id, sex, age_group_name, age, pop_age, n_osa_0v, n_osa_1v, n_osa_2v, n_osa_99v)
        final <- pop_filt %>% rbind(pop_new)
      }else{
        final <- final %>% rbind(pop_new)
      }
      final[is.na(final)] <- 0 
    }
    close(pb)
    
    # min(final$year_id)
    
    
    # AFTER SIMULATION  -----
    # View(final %>% filter(year_id == 2030))   ## TODO korjattava useamman vuoden diganoosi n
    ## Summarise outcomes ----
    final_aggr <- final %>% 
      dplyr::group_by(location_name, year_id, sex, age_group_name) %>% 
      dplyr::summarise(
        pop = round(sum(pop_age, na.rm = T), 0),
        n_osa_0v = sum(n_osa_0v, na.rm = T),
        n_osa_1v = sum(n_osa_1v, na.rm = T),
        n_osa_2v = sum(n_osa_2v, na.rm = T),
        n_osa_99v = sum(n_osa_99v, na.rm = T),
      ) %>% 
      mutate(
        pop_osa = round(n_osa_0v + n_osa_1v + n_osa_2v + n_osa_99v, 0),
        prevalence = pop_osa / pop, 
        incidence = n_osa_0v / pop
      )
    
    # min(final_aggr$year_id)
    
    
    
    ## Cost data ----
    
    ## Intervention data change -----
    if(intervention){
      d1 <- cost_osa %>% 
        filter(sex == "female")
      d2 <- cost_osa %>% 
        filter(sex == "male")
      ## muutos vain male->female
      d1 <- d2 %>% 
        mutate(sex="female")
      cost_osa <- d1 %>% 
        rbind(d2)
    }
    
    ## Cost by multiplying cases * average cost -----
    
    ## Lasketaan kustannukset yksinkertaisella kertolaskulla
    final_aggr <- final_aggr %>% 
      left_join(cost_osa, by = c("sex", "age_group_name")) %>% 
      mutate(
        total_cost = (n_osa_0v * kust0) + (n_osa_1v * kust1) + (n_osa_2v * kust2) + (n_osa_99v * kust2),
        total_cost_patient = total_cost / pop_osa,
        total_cost0v = n_osa_0v * kust0 ,
        total_cost_patient_0v = total_cost0v / n_osa_0v,
        total_cost1v = n_osa_1v * kust1,
        total_cost_patient_1v = total_cost1v / n_osa_1v,
        total_cost2v = n_osa_2v * kust2,
        total_cost_patient_2v = total_cost2v / n_osa_2v,
        total_cost99v = n_osa_99v * kust2,
        total_cost_patient_99v = total_cost99v / (n_osa_99v)
      ) %>% 
      select(location_name, 
             year_id, sex, 
             age_group_name, 
             pop, 
             n_osa_0v, 
             n_osa_1v, 
             n_osa_2v, 
             n_osa_99v, 
             pop_osa, 
             prevalence, 
             incidence, 
             total_cost, 
             total_cost_patient, 
             total_cost0v, 
             total_cost_patient_0v, 
             total_cost1v, 
             total_cost_patient_1v, 
             total_cost2v, 
             total_cost_patient_2v, 
             total_cost99v, 
             total_cost_patient_99v)
    
    
    # DATA OUTPUT ----
    
    # ## Write invidual Arrow Parquet to outputdir 
    # if(WRITE_DATA){
    #   arrow::write_parquet(x = final_aggr, sink = paste0(data_output, cntry, ".parquet"))
    # }
    
    ## Make fulldata 
    fulldata <- fulldata %>% 
      rbind(final_aggr)
    
  } # FOR-LOOP END
  
  # Kokoa aineistot yhteen kansiosta tiedoksi  osapredict.parquet
  if(WRITE_DATA){
    if(!dir.exists(data_output)) dir.create(data_output)
    if(WRITE_NAME != ""){
      ## TODO parquet file name fix
      arrow::write_parquet(fulldata, paste0(data_output, WRITE_NAME,".parquet"))
    }else{
      arrow::write_parquet(fulldata, paste0(data_output, "osasimulation.parquet"))
    }
  }else{
    return(fulldata)
  }
}



## Parquet read by duckdb func
read_parquet <- function(file) {
  ct <- DBI::dbConnect(duckdb::duckdb())
  q <- DBI::dbGetQuery(ct, paste0("FROM read_parquet('",file,"');"))
  DBI::dbDisconnect(ct, shutdown=TRUE)
  return(q)
}
