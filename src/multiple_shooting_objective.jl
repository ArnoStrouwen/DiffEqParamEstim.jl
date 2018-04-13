export multiple_shooting_objective
function multiple_shooting_objective(prob::DEProblem,alg,loss,init_N_params,regularization=nothing;mpg_autodiff = false,
                              verbose_opt = false,prob_generator = problem_new_parameters,autodiff_prototype = mpg_autodiff ? zeros(init_N_params) : nothing,
                              autodiff_chunk = mpg_autodiff ? ForwardDiff.Chunk(autodiff_prototype) : nothing,
                              kwargs...)
  cost_function = function (p)
    N = length(p)-2
    time_len = Int(floor(length(loss.t)/N))
    time_dur = loss.t[1:time_len]
    sol = []
    loss_val = 0
    for i in 1:2:N
        tmp_prob = remake(prob;u0=p[i:i+1],p=[N+1:N+2])
        if typeof(loss) <: Union{CostVData,L2Loss,LogLikeLoss}
          # println("huihui1")
          push!(sol,solve(tmp_prob,alg;saveat=time_dur,save_everystep=false,dense=false,kwargs...))
          # println("huihui2")
          if (i+1)*time_len < length(loss.t)
            time_dur = loss.t[i*time_len:(i+1)*time_len]
          else
            time_dur = loss.t[i*time_len:Int(length(loss.t))]
          end
        else
          push!(sol,solve(tmp_prob,alg;kwargs...))
        end

        if regularization == nothing
            loss_val += loss(sol[i])
        else
            loss_val += loss(sol[i]) + regularization(p[N:end])
        end
      end
    if verbose_opt
        count::Int += 1
        if mod(count,verbose_steps) == 0
          println("Iteration: $count")
          println("Current Cost: $loss_val")
          println("Parameters: $p")
        end
    end
    loss_val
  end
    if mpg_autodiff
      gcfg = ForwardDiff.GradientConfig(cost_function, autodiff_prototype, autodiff_chunk)
      g! = (x, out) -> ForwardDiff.gradient!(out, cost_function, x, gcfg)
    else
      g! = (x, out) -> Calculus.finite_difference!(cost_function,x,out,:central)
    end
    cost_function2 = function (p,grad)
      if length(grad)>0
          g!(p,grad)
      end
      cost_function(p)
    end
  DiffEqObjective(cost_function,cost_function2)
end