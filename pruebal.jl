using LinearAlgebra
using DataFrames
using CSV
using StatsPlots
using SparseArrays
using Statistics
using PrettyTables


##___________________________________________________________________________
function carga_datos() # Cargar los datos
    lin = DataFrame(CSV.File("lines.csv")) # Datos de las líneas
    nod = DataFrame(CSV.File("nodes.csv")) # Datos de los nodos
    num_nod = nrow(nod) # Número de nodos
    num_lin = nrow(lin) # Número de líneas    
    return lin, nod, num_lin, num_nod # Se retornan los DataFrames y el número de nodos y líneas
end
##___________________________________________________________________________
function crear_Ykm(lin, nod) # Crear la matriz de admitancias
    num_nod = nrow(nod) # Número de nodos 
    num_lin = nrow(lin) # Número de líneas
    
    Ykm = zeros(num_nod, num_nod) # Matriz de admitancias
    
    for i in 1:num_lin # Se recorre cada línea
        k = lin.FROM[i] # Nodo de inicio
        m = lin.TO[i] # Nodo final
        Y_km =  1 / (lin.X[i]) # Admitancia de la línea
        
        Ykm[k, m] -= Y_km # Fuera
        Ykm[m, k] -= Y_km # Fuera
        Ykm[k, k] += Y_km # Diagonal
        Ykm[m, m] += Y_km # Diagonal
    end
    return Ykm # Se retorna la matriz de admitancias
end
##___________________________________________________________________________
# Eliminar nodo slack (primer nodo) en la matriz Ybus
function reducir_Ybus(Ybus) # Reducir la matriz de admitancias
    Ybus_red = copy(Ybus) # Se copia la matriz
    Ybus_red[1, :] .= 0  # Primera fila a ceros
    Ybus_red[:, 1] .= 0  # Primera columna a ceros
    return Ybus_red
end
##___________________________________________________________________________
# Calcular la inversa de la matriz reducida de Ybus
function inversa_Ybus(Ybus_red) # Inversa de la matriz de admitancias reducida
    return pinv(Ybus_red)  # Se usa la pseudo-inversa en caso de singularidad
end
##___________________________________________________________________________
# Calcular el Generation Shift Factor (GSF)
function calcular_GSF(Ybus_inv, lin, nod) # Calcular el Generation Shift Factor
    # Identificar nodos generadores
    gen_nodes = findall(nod.PGEN .> 0) # se explora el vector de generación, ubicando los nodos generadores, devuelve el bus(posicion) donde se encuentra 
    num_lin = nrow(lin) # Número de líneas
    GSF = zeros(num_lin, length(gen_nodes)) # Matriz de Generation Shift Factor

    for j in 1:length(gen_nodes) # Se recorren los nodos generadores
        i = gen_nodes[j]  # Nodo generador
        for l in 1:num_lin # Se recorren las líneas
            k = lin.FROM[l] # Extremo 1 de la línea
            m = lin.TO[l]   # Extremo 2 de la línea
            xl = lin.X[l]   # Reactancia de la línea

            Wki = Ybus_inv[k, i] # se calcula calcula el flujo de potencia en el nodo i respecto a la linea k
            Wmi = Ybus_inv[m, i] # se calcula calcula el flujo de potencia en el nodo i respecto a la linea m

            GSF[l, j] = (1 / xl) * (Wki - Wmi) # se calcula el generation shift factor en los buses de generacion
        end
    end
    return GSF
end
##___________________________________________________________________________
function calcular_LODF(X, lin) # Calcular el Line Outage Distribution Factor
    num_lin = nrow(lin) # Número de líneas
    LODF = zeros(num_lin, num_lin)  # Matriz de factores de salida de línea

    for k in 1:num_lin  # Línea que se abre
        x_k = lin[k, :X]  # Reactancia de la línea k
        n_k = lin[k, :FROM]  # Nodo de inicio de la línea k
        m_k = lin[k, :TO]  # Nodo de fin de la línea k

        X_nn = X[n_k, n_k]  # Elemento diagonal nodo n
        X_mm = X[m_k, m_k]  # Elemento diagonal nodo m
        X_nm = X[n_k, m_k]  # Elemento fuera de la diagonal

        den = x_k - (X_nn + X_mm - 2 * X_nm)  # Denominador

        for l in 1:num_lin  # Línea afectada
            if l == k # Evitar la diagonal
                LODF[l, k] = 0  # La diagonal debe ser cero
            else
                x_l = lin[l, :X]  # Reactancia de la línea l
                n_l = lin[l, :FROM]  # Nodo de inicio de la línea l
                m_l = lin[l, :TO]  # Nodo de fin de la línea l

                X_in = X[n_l, n_k]  # Elemento de la matriz X  
                X_im = X[n_l, m_k]  # Elemento de la matriz X
                X_jn = X[m_l, n_k]  # Elemento de la matriz X
                X_jm = X[m_l, m_k]  # Elemento de la matriz X

                num = (x_k / x_l) * (X_in - X_jn - X_im + X_jm)  # Numerador

                if den != 0 # Evitar división por cero
                    LODF[l, k] = num / den # Factor de distribución de salida de línea
                else
                    LODF[l, k] = 0  # Manejo de división por cero
                end
            end
        end
    end
    return LODF
end
##_________________________________________________________________
function main()
    lin, nod, num_lin, num_nod = carga_datos() # Cargar los datos
    Ybus = crear_Ykm(lin, nod) # Crear la matriz de admitancias
    Ybus_red = reducir_Ybus(Ybus)  # Se elimina el nodo slack
    Ybus_inv = inversa_Ybus(Ybus_red)  # Se obtiene la inversa de la Ybus reducida
    GSF = calcular_GSF(Ybus_inv, lin, nod)  # Se calcula el Generation Shift Factor
    LODF = calcular_LODF(Ybus_inv, lin)

    println("Matriz Ybus reducida:")
    pretty_table(Ybus_red)

    println("Matriz inversa de Ybus reducida:")
    pretty_table(Ybus_inv)

    println("Generation Shift Factors (GSF):")
    pretty_table(GSF)

    println("Line Outage Distribution Factors (LODF):")
    pretty_table(LODF)

    return nothing
end
# Llamada a la función principal
main()