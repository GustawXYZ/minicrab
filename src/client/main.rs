use bevy::prelude::*;
use std::time::Instant;

#[derive(Component)]
struct Player;

#[derive(Component)]
struct Name(String);

#[derive(Debug, Component)]
struct Position {
    x: f32,
    y: f32,
    z: f32,
    time: Instant,
}

#[derive(Debug, Component)]
struct Velocity {
    x: f32,
    y: f32,
    z: f32,
}

fn spawn_player_system(mut commands: Commands) {
    commands.spawn((
        Player,
        Name("Gustaw".to_string()),
        Position {
            x: 0.0,
            y: 0.0,
            z: 0.0,
            time: Instant::now(),
        },
        Velocity {
            x: 0.0,
            y: 1.0,
            z: 0.0,
        },
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

fn move_positions_system(mut query: Query<(&mut Position, &Velocity)>) {
    for (mut position, velocity) in &mut query {
        let now = Instant::now();
        let seconds_delta = (now - position.time).as_secs_f32();
        position.time = now;
        position.x += velocity.x * seconds_delta;
        position.y += velocity.y * seconds_delta;
        position.z += velocity.z * seconds_delta;
    }
}

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_systems(Startup, spawn_player_system)
        .add_systems(Update, (move_positions_system, list_players_system).chain())
        .run();
}
