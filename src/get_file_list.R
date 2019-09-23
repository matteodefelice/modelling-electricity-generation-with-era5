get_file_list <- function() {
  if (!file.exists('prod_stats.rds')) {
    stop('You should run 00 script before!')
  }
  return(
    read_delim('file_list.csv', delim = ';') %>%
      dplyr::filter(active == 1) %>%
      dplyr::filter(country != 'BA') %>% 
      left_join(read_rds('prod_stats.rds')) %>% 
      dplyr::filter(!is.infinite(max), q95 > 100) 
  )
}