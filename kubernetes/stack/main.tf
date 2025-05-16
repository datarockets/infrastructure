locals {
  stack_secret_names     = keys(var.secrets)
  stack_config_map_names = keys(var.config_maps)

  config_maps_mentioned = distinct(compact(flatten([
    for _, component in var.components : [
      component.env.from_config_maps,
      coalesce(component.init_container.env.from_config_maps, []),
      [for mount in component.mounts : mount.config_map],
      [for mount in coalesce(component.init_container.mounts, []) : mount.config_map],
    ]
  ])))

  secrets_mentioned = distinct(compact(flatten([
    for _, component in var.components : [
      component.env.from_secrets,
      coalesce(component.init_container.env.from_secrets, []),
      [for mount in component.mounts : mount.secret],
      [for mount in coalesce(component.init_container.mounts, []) : mount.secret],
    ]
  ])))

  external_config_map_names = setsubtract(
    local.config_maps_mentioned,
    local.stack_config_map_names,
  )

  external_secret_names = setsubtract(
    local.secrets_mentioned,
    local.stack_secret_names,
  )
}
