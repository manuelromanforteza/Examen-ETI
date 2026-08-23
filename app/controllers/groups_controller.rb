class GroupsController < ApplicationController
  before_action :require_group!, only: :waiting

  def new
    # If already logged in, go straight to strategies or waiting room
    if current_group
      redirect_to current_group.selection ? waiting_path : strategies_path
    end
  end

  def create
    tournament = active_session
    name = params[:name].to_s.strip
    pin  = params[:pin].to_s.strip

    if name.blank? || pin.blank?
      flash.now[:alert] = "Nombre y PIN son obligatorios."
      return render :new, status: :unprocessable_entity
    end

    unless pin.match?(/\A\d{4}\z/)
      flash.now[:alert] = "El PIN debe ser exactamente 4 dígitos."
      return render :new, status: :unprocessable_entity
    end

    group = tournament.groups.find_by(name: name)

    if group
      # Existing group: authenticate PIN
      unless group.authenticate_pin(pin)
        flash.now[:alert] = "PIN incorrecto para ese nombre de grupo."
        return render :new, status: :unprocessable_entity
      end
    else
      # New group: create with hashed PIN
      group = tournament.groups.create!(name: name, pin: pin)
    end

    session[:group_id] = group.id
    redirect_to group.selection ? waiting_path : strategies_path,
                notice: "¡Bienvenido, #{group.name}!"
  end

  def destroy
    session.delete(:group_id)
    redirect_to join_path, notice: "Sesión cerrada."
  end

  def waiting
    @group    = current_group
    @strategy = @group.strategy
    @tournament = @group.session
    @total_groups   = @tournament.groups.count
    @ready_groups   = @tournament.groups.joins(:selection).count
  end
end
