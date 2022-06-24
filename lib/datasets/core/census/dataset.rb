# frozen_string_literal: true

# SOURCE: https://www.census.gov/geographies/mapping-files/time-series/geo/carto-boundary-file.html
# INFO: https://www.census.gov/programs-surveys/geography/technical-documentation/naming-convention/cartographic-boundary-file.html

# ogrinfo -rl -so cb_2018_us_county_500k.shp
# INFO: Open of `cb_2018_us_county_500k.shp'
#       using driver `ESRI Shapefile' successful.

# Layer name: cb_2018_us_county_500k
# Metadata:
#   DBF_DATE_LAST_UPDATE=2019-04-15
# Geometry: Polygon
# Feature Count: 3233
# Extent: (-179.148909, -14.548699) - (179.778470, 71.365162)
# Layer SRS WKT:
# GEOGCRS["NAD83",
#     DATUM["North American Datum 1983",
#         ELLIPSOID["GRS 1980",6378137,298.257222101,
#             LENGTHUNIT["metre",1]]],
#     PRIMEM["Greenwich",0,
#         ANGLEUNIT["degree",0.0174532925199433]],
#     CS[ellipsoidal,2],
#         AXIS["latitude",north,
#             ORDER[1],
#             ANGLEUNIT["degree",0.0174532925199433]],
#         AXIS["longitude",east,
#             ORDER[2],
#             ANGLEUNIT["degree",0.0174532925199433]],
#     ID["EPSG",4269]]
# Data axis to CRS axis mapping: 2,1
# STATEFP: String (2.0)
# COUNTYFP: String (3.0)
# COUNTYNS: String (8.0)
# AFFGEOID: String (14.0)
# GEOID: String (5.0)
# NAME: String (100.0)
# LSAD: String (2.0)
# ALAND: Integer64 (14.0)
# AWATER: Integer64 (14.0)

def extract
  data_dir = 'data'
  county_data = File.join(data_dir, 'cb_2018_us_county_500k.shp')
  ogr2ogr_cmd = Rails.configuration.x.datasets[:constants][:OGR2OGR_CMD]
  pg_db = Rails.configuration.database_configuration[Rails.env]
  pg_db_name = pg_db['database']
  pg_db_user = pg_db['username']
  pg_conn = "dbname='#{pg_db_name}' user='#{pg_db_user}'"
  relpath = File.dirname(__FILE__).to_s

  DatasetsHelper.fetch_resource('https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_county_500k.zip',
                                base_dir: relpath,
                                extract: true,
                                extract_dir: File.join(relpath.to_s, data_dir))

  # Copy shapefile into PG - Filter out the islands (Guam, Puerto Rico, etc.)
  `#{ogr2ogr_cmd} PG:"#{pg_conn}" #{File.join(relpath, county_data)} -nln  "counties" -nlt "MULTIPOLYGON" -s_srs "EPSG:4269" -t_srs "EPSG:4326"`

  # Union SQL statement to generate U.S. boundary shape (we just merge all counties)
  `psql wigeo wid \
         -c "DROP TABLE IF EXISTS us_boundary; \
            CREATE TABLE us_boundary (id varchar(12), geometry geometry); \
            INSERT INTO us_boundary (id, geometry) VALUES ('us50+terr', (SELECT ST_Union(counties.wkb_geometry) FROM counties)); \
            INSERT INTO us_boundary (id, geometry) VALUES ('us50', (SELECT ST_Union(counties.wkb_geometry) FROM counties WHERE statefp NOT IN ('60', '66', '69', '72', '78'))); \
            INSERT INTO us_boundary (id, geometry) VALUES ('us48', (SELECT ST_Union(counties.wkb_geometry) FROM counties WHERE statefp NOT IN ('02', '15', '60', '66', '69', '72', '78')));"`
end

extract
