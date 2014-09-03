/*
Looking at impact of five best practices on patient level outcomes
Best practices:
1. MD on call
2. Pain monitored at least every few days (vs less)
3. Symptoms monitored at least every few days (vs less)
4. Goals of care discussed at all 3 time points
5. Family preferences discussed at all 3 time points

Patient level outcomes (all binary):
1. Hospital admission
2. ED use (from IP or OP claims)
3. ICU use

Dataset exported from SAS at the end of the table1.sas code
*/

capture log close
clear all
set more off

local datapath J:\Geriatrics\Geri\Hospice Project\Hospice\working
local logpath J:\Geriatrics\Geri\Hospice Project\output

log using "`logpath'\meglm_stata_work-LOG.txt", text replace

cd "`datapath'"
use ltd_vars_for_analysis.dta

compress
/*
*********************************************************
local outcomes hosp_adm_ind ip_ed_visit_ind icu_stay_ind
foreach v in `outcomes'{
tab `v', missing
}

local xvars female agecat re_white cancer cc_grp ownership1 sizecat region1
foreach v in `xvars'{
tab `v', missing
}

local bpvars smd_on_call pan_efd symp_efd  poc_gocall3 fp_all3
foreach v in `bpvars'{
tab `v', missing
}

local region county_state beds_2009 nursing_beds_2009 per_cap_inc_2009 ///
census_pop_2010 urban_cd
foreach v in  `region'{
sum `v', detail
}*/

//per email 8/29 variables to control for are hospital beds/1000 residents
//urban indicator and per captia income
la var urban_cd "Urban county indicator"
la def urban_cd 1 "Urban" 0 "Rural"
la val urban_cd urban_cd
tab urban_cd, missing

gen hospital_beds_per_res = beds_2009 / census_pop_2010
sum hospital_beds_per_res, detail
la var hospital_beds_per_res "Hospital beds per 1000 residents"

gen agecat2 = .
forvalues i = 1/5{
replace agecat2 = `i' if agecat=="     `i'"
}

la var agecat2 "Age at enrollment, categorical"
la def agecat2 1 "Age 65-69" 2 "Age 70-74" 3 "Age 75-79" 4 "Age 80-84" 5 "Age 85+"
la val agecat2 agecat2
tab agecat2, missing

//addtional variable labels
la var female "Female"
la var re_white "White, non-Hispanic"
la var cancer "Primary diagnosis = cancer"
la var cc_grp "Count of chronic conditions, categorical"
la def cc_grp 0 "None" 1 "One" 2 "Two+"
la val cc_grp cc_grp
la var ownership1 "Hospice ownership"
la def ownership1 1"Nonprofit" 2"For profit"
la val ownership1 ownership1
la var sizecat "Hospice size, no. beds, cat."
la def sizecat 1 "<250" 2 "250-599" 3 "600-1299" 4 "1300+"
la val sizecat sizecat
la var region1 "Hospice region"
la def region1 1 "New England/ Mid-Atlantic" 2 "E/W North Central" ///
	3 "South Atlantic" 4 "E/W South Central" 5 "Mountain/Pacific"
la val region1 region1
/*
//replicate means comparison across outcome categories
foreach v in `bpvars' `xvars'{
tab `v' hosp_adm_ind, missing
tab `v' ip_ed_visit_ind, missing
tab `v' icu_stay_ind, missing
}
*/

/*sas code trying to replicate
proc genmod data=table5 descending;
class pos1 ip_ed_visit_ind (ref = '0') &var (ref = '0')
ownership1 (ref = '2') agecat(ref = '1') re_white (ref = '0') 
cancer (ref = '0') CC_grp(ref = '0') sizecat(ref = '1') 
region1 (ref = '3') / param = ref;
model icu_stay_ind = &var female agecat re_white cancer cc_grp ownership1 sizecat region1
/dist=bin link=logit type3 wald ;
repeated subject=pos1/type=exch;
***where &var is each of the best practices
***class = pos1 - hospice identifier - clustered in repeated subject option
type3 = type 3 analysis, provides likelihood ratio tests for each parameter
wald = wald confidence intervals
*** /type=exch specifies the correlation matrix structure, exch=exchangeable
Per Melissa, it was the best fit on similar analysis before so we used it
for this initial analysis*/

/*local xvars2 i.female ib1.agecat2 i.re_white i.cancer ib0.cc_grp ///
	ib2.ownership1 ib1.sizecat ib3.region1

glm hosp_adm_ind smd_on_call `xvars2' , family(binomial) link(logit) vce(cluster pos1) 
glm, eform*/

//can't run this b/c matsize too small! can't set it > 800 in stata IC
//xtset pos1
//xtgee hosp_adm_ind smd_on_call `xvars2',family(binomial) link(probit) corr(exchangeable) eform

//check correlation, from Degenholz, ICC > 0.05 then correlation needs to be accounted for
loneway hosp_adm_ind pos1 //by hospice
loneway hosp_adm_ind region1 //by region
loneway hosp_adm_ind county_state //by county

local xvars3 i.female ib1.agecat2 i.re_white i.cancer ib0.cc_grp ///
	ib2.ownership1 ib1.sizecat

local regvars i.urban_cd hospital_beds_per_res per_cap_inc_2009

meglm hosp_adm_ind smd_on_call `xvars3' `regvars' || region1: || pos1: , ///
family(binomial) link(logit) diff

estimates save meglm_est, replace

*********************************************************
log close
