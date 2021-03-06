create_lake_task_makefile <- function(makefile, task_plan, remake_file, final_targets) {
  scipiper::create_task_makefile(
    makefile=makefile, task_plan=task_plan,
    include=remake_file,
    packages=c("purrr", "dplyr", "mda.lakes", "feather", "rLakeAnalyzer"),
    final_targets = final_targets,
    sources=c("2_process/src/calculate_toha.R")
  )
}

create_lake_tasks <- function(task_df_fn, log_folder){

  tasks <- tibble(task_filepath = names(yaml::yaml.load_file(task_df_fn))) %>% 
    mutate(filename = basename(task_filepath)) %>% 
    extract(filename, c('prefix','site_id','suffix'), "(pb0|pball|pgdl)_data_(.*)(.feather)", remove = FALSE) %>% 
    select(task_filepath, site_id, prefix) %>% 
    filter(nchar(task_filepath) != 0) 
    
  model_type = pull(tasks, prefix) %>% unique()
  stopifnot(length(model_type) == 1)
  toha_step_name <- sprintf('calculate_%s_toha', model_type)
  
  #' I'm doing this because each toha task is slow running
  #' and if `morphometry` changes, we don't want to have to re-run all of them,
  #' just the ones where _their_ morphometry changed. So we are subsetting first. 
  split_morphometry <- scipiper::create_task_step(
    step_name = 'split_morphometry',
    target_name = function(task_name, step_name, ...){
      
      sprintf("%s_morphometry", task_name)
    },
    command = function(task_name, ...){
      task_filepath <- dplyr::filter(tasks, site_id == task_name) %>% 
        pull(task_filepath)
      sprintf("morphometry[[I('%s')]]", task_name)
    } 
  )
  
  calculate_model_toha <- scipiper::create_task_step(
    step_name = toha_step_name,
    target_name = function(task_name, step_name, ...){
      
      sprintf("2_process/tmp/%s_toha_%s.csv", model_type, task_name)
    },
    command = function(task_name, ...){
      task_filepath <- dplyr::filter(tasks, site_id == task_name) %>% 
        pull(task_filepath)
      psprintf("calculate_toha_per_lake(", 
               "target_name = target_name,",
               "site_data_fn = '%s'," = task_filepath,
               "morphometry = `%s_morphometry`)" = task_name
      )
    } 
  )
  
  # ---- combine into a task plan ---- #
  
  gif_task_plan <- scipiper::create_task_plan(
    task_names=tasks$site_id,
    task_steps=list(split_morphometry,
      calculate_model_toha),
    add_complete=FALSE,
    final_steps=c(toha_step_name),
    ind_dir='2_process/log')
}
