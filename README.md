# supervisor
A process supervisor (similar to python's supervisord) implemented in Crystal.

## Build ``` sv ```
```
crystal build src/sv.cr
```

## Usage
```sv``` is expected to be run from a directory which has the following structure:
```
.
├── config
│   ├── jobs.yml
│   └── sv.yml
├── log
└── tmp
```
### Config
```sv``` needs the following config files to run:
- ```config/jobs.yml``` : used to declare job/process definitions like command, working_dir, arguments, env etc
- ```config/sv.yml``` : used to specify no. of job instances and job config overrides.

### Commands
- To start the supervisor along with the process defined in jobs.yml/sv.yml use:
  ```
  sv rr
  ```

- To check status use:
  ```
  sv status
  ```

- To shutdown the supervisor and all the managed processes use:
  ```
  sv shutdown
  ```

- To see all available commands use
  ```
  sv help
  ```
### Demo
  A demo/ directory is included in the git repo. It includes 
  - two shell scripts **app-a**, **app-b** which logs some text to stdout/stderr in a loop. 
  - preconfigured ```config/jobs.yml``` and ```config/sv.yml``` which use the above scripts.
  
  To run the demo:
  ```
  $ cd demo
  $ ../sv rr # to start sv
  $ ../sv status # to see sv status
  $ ../sv shutdown
  ```
  
