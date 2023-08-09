/*

Covid-19 data exploration

*/

-- CFR
-- To look at the case fatality rate (CFR)
-- It is the number of deaths divided by the number of confirmed cases
-- Due to this there are better way to determine the lethality of a disease worldwide such as IFR
select location, date, total_deaths, total_cases, CAST(total_deaths AS float)/NULLIF(total_cases,0)*100 as CFR
from sales.dbo.coviddeaths
order by 1, 2; 



-- OBSERVED CASE FATALITY RATIO for India--
-- We see that the CFR is highest in 2020
-- At present, the CFR for India is 1.2%
select location, date, total_deaths, total_cases, CAST(total_deaths AS float)/NULLIF(total_cases,0)*100 as CFR
from sales.dbo.coviddeaths
where location like 'India'
order by 2; 


-- Positive cases per capita --
-- Positive cases in an area divided by the population
-- We see that on 2021-04-16, 1% of the population was infected in India
-- As of 2023-04-12 only 3.2% of the population has been infected by Covid-19
select location, date, total_cases, population, (CAST(total_cases AS DECIMAL(16,2))/population)*100 as cases_per_capita
from sales.dbo.coviddeaths
where location like 'India'
order by 2; 


-- Positive cases per capita for each country --
-- We see that Cyprus has the highest cases per capita for Covid-19
select location, population, max(CAST(total_cases AS DECIMAL(16,2))/population*100) as cases_per_capita
from sales.dbo.coviddeaths
group by location, population
order by 3 desc;


-- Total Deaths per Country
-- Here the US has the highest deaths with 1,118,800 deaths
-- India has the third highest total deaths
select location, max(cast(total_deaths as int)) as 'Total Deaths'
from sales.dbo.coviddeaths
where continent is not null
group by location
order by 2 desc;

-- Total Deaths per Continent
select location, max(cast(total_deaths as int)) as 'Total Deaths'
from sales.dbo.coviddeaths
where continent is null
group by location
order by 2 desc;

-- Mortality per 100,000 people for India
-- As of 2023-04-12, for India it is 37.46. Which means at the latest date ~38 people died for every 100k people
select location, date, total_deaths, population, (CAST(total_deaths AS DECIMAL(16,2))/population)*100000 as mortality
from sales.dbo.coviddeaths
where location like 'India'
order by 2; 

-- Mortality per 100,000 people per country
-- Peru has the highest mortality per 100k at 646 deaths/100k of population
select location, max(cast(population as bigint)), MAX((CAST(total_deaths AS DECIMAL(16,2))/population))*100000 as mortality
from sales.dbo.coviddeaths
where continent is not null
group by location
order by 3 desc; 

-- Mortality per 100,000 people per continent
-- South America has the highest mortality per 100k at 310 deaths/100k of population
select location, max(cast(population as bigint)), MAX((CAST(total_deaths AS DECIMAL(16,2))/population))*100000 as mortality
from sales.dbo.coviddeaths
where continent is null
group by location
order by 3 desc; 


-- Global numbers

-- Let's look at the number of infections
-- Positive cases per capita. This means total cases/total population
-- 9.6% of the world's population was infected with Covid-19
select location, max(total_cases) as TotalCases, population, max((CAST(total_cases AS DECIMAL(16,2))/population)*100) as cases_per_capita
from sales.dbo.coviddeaths
where location like 'world'
group by location, population;

-- Let's look at the number of deaths among the infected
-- Case Fatality Rate (CFR)
-- 7.6% of infections resulted in death
select location, max(total_cases) as TotalCases, max(total_deaths) as TotalDeaths, max(CAST(total_deaths AS DECIMAL(16,2))/NULLIF(total_cases,0))*100 as CaseFatalityRate
from sales.dbo.coviddeaths
where location like 'world'
group by location;


-- Total Deaths
-- Covid-19 resulted in around 6.9m recorded deaths
select location, max(total_deaths) as TotalDeaths
from sales.dbo.coviddeaths
where location like 'world'
group by location;


-- Mortality per 100,000 people 
-- Around 86 people died for every 100k people
select location, max(cast(population as bigint)), MAX((CAST(total_deaths AS DECIMAL(16,2))/population))*100000 as mortality
from sales.dbo.coviddeaths
where location like 'world'
group by location; 

-- Using partition

Select 
	dea.continent, 
	dea.location, 
	dea.date, 
	dea.population, 
	vac.new_vaccinations, 
	SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as vaccines_rolling
--, (RollingPeopleVaccinated/population)*100
From sales.dbo.coviddeaths dea
Join sales.dbo.covidvaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
order by 2,3


-- Using CTE

With vaccination_percent (continent, location, date, population, new_vacc, vacc_rolling) As (
	Select 
		dea.continent, 
		dea.location, 
		dea.date, 
		dea.population, 
		vac.new_vaccinations, 
		SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as vaccines_rolling
	--, (RollingPeopleVaccinated/population)*100
	From sales.dbo.coviddeaths dea
	Join sales.dbo.covidvaccinations vac
		On dea.location = vac.location
		and dea.date = vac.date
	where dea.continent is not null 
)

select 
	*,
	cast(vacc_rolling as float)/population*100 as rollingpercent
from vaccination_percent
order by location,date;


-- Using Temp Table
DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From sales.dbo.coviddeaths dea
Join sales.dbo.covidvaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
order by 2,3


select *
from #PercentPopulationVaccinated

-- Rolling People Vaccinated for each country
Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From sales.dbo.coviddeaths dea
Join sales.dbo.covidvaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 





-- Creating  views

-- 1. 
-- Rolling number of people vaccinated

Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population,
max(vac.total_vaccinations)as RollingPeopleVaccinated
From sales.dbo.coviddeaths dea
Join sales.dbo.covidvaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
group by dea.continent, dea.location, dea.date, dea.population

-- 2. 
-- CFR
Create View CaseFatalityRate as
select max(total_deaths) as TotalDeaths, max(total_cases) as TotalCases, max(CAST(total_deaths AS float)/NULLIF(total_cases,0)*100) as CFR
from sales.dbo.coviddeaths
where location like 'world'; 

Select * from CaseFatalityRate

-- 3. 
-- Total Deaths

Create view TDeathsContinents as
select location, max(cast(total_deaths as int)) as 'Total Deaths'
from sales.dbo.coviddeaths
where continent is  null and location not like 'world'
group by location;

-- 4.
-- Infection Postive cases per capita
--drop view if exists casesPerCapita
--create view casesPerCapita as
--select location, max(population) as population, max(date) as date, max(CAST(total_cases AS DECIMAL(16,2))/population*100) as cases_per_capita
--from sales.dbo.coviddeaths
--group by location;



create view casesPerCapita as
select location, population, date, max(total_cases) as highestInfectionCount, max(CAST(total_cases AS DECIMAL(16,2))/population*100) as cases_per_capita
from sales.dbo.coviddeaths
group by location, population, date





---------------------------------------------------------------------------
-- Testing section
select distinct location
from sales.dbo.coviddeaths;

select *
from sales.dbo.coviddeaths;

select continent from sales.dbo.coviddeaths
where continent is null;

INSERT INTO sales.dbo.coviddeaths (continent)
VALUES (NULLIF('$jobTitle', ''));

UPDATE sales.dbo.coviddeaths SET continent = NULL WHERE continent = '';

select *
from sales.dbo.coviddeaths
where location like 'Asia';

select continent, location
from sales.dbo.coviddeaths
where continent is null;

