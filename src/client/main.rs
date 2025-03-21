use bevy::prelude::*;

#[derive(Component)]
struct Player;

#[derive(Component)]
struct Name(String);

#[derive(Debug, Component)]
struct Position(Vec3);

#[derive(Debug, Component)]
struct Velocity(Vec3);

fn spawn_player_system(
    mut commands: Commands,

    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    // player
    commands.spawn((
        Player,
        Name("Gustaw".to_string()),
        Position(Vec3::new(0., 0., 0.)),
        Velocity(Vec3::new(0., 0.1, 0.)),
        Mesh3d(meshes.add(Cuboid::new(1.0, 1.0, 1.0))),
        MeshMaterial3d(materials.add(Color::srgb_u8(124, 144, 255))),
        Transform::from_xyz(0.0, 0.0, 0.0),
    ));
    // light
    commands.spawn((
        PointLight {
            shadows_enabled: true,
            ..default()
        },
        Transform::from_xyz(4.0, 8.0, 4.0),
    ));
    // camera
    commands.spawn((
        Camera3d::default(),
        Transform::from_xyz(-2.5, 4.5, 9.0).looking_at(Vec3::ZERO, Vec3::Y),
    ));
}

fn list_players_system(query: Query<(&Name, &Position, &Velocity), With<Player>>) {
    for (name, position, velocity) in &query {
        println!(
            "Player {} pos({:?}) velocity({:?})",
            name.0, position, velocity
        );
    }
}

fn move_positions_system(
    time: Res<Time>,
    mut query: Query<(&mut Position, &mut Transform, &Velocity)>,
) {
    for (mut position, mut transform, velocity) in &mut query {
        let seconds_delta = time.delta_secs();
        position.0.x += velocity.0.x * seconds_delta;
        position.0.y += velocity.0.y * seconds_delta;
        position.0.z += velocity.0.z * seconds_delta;
        transform.translation = position.0;
    }
}

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_systems(Startup, spawn_player_system)
        .add_systems(Update, (move_positions_system, list_players_system).chain())
        .run();
}
