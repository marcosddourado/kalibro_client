Feature: Repositories listing
  In order to be able to check know if a repository still exists
  As a developer
  I want to check that on the service

  @kalibro_processor_restart @kalibro_configuration_restart
  Scenario: With existing project repository
    Given I have a project with name "Kalibro"
    And I have a kalibro configuration with name "Conf"
    And the given project has the following Repositories:
      |   name    | scm_type |                       address                    |
      |  Kalibro  |    GIT   | https://github.com/mezuro/kalibro_processor.git  |
    When I ask to check if the given repository exists
    Then I should get true
